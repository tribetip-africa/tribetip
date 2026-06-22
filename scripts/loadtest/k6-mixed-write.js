import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

const baseUrl = __ENV.BASE_URL || "http://api:80";
const hostHeader = __ENV.HOST_HEADER || "localhost";
const readRpm = Number(__ENV.READ_RPM || __ENV.TARGET_RPM || 9500);
const writeRpm = Number(__ENV.WRITE_RPM || 60);
const duration = __ENV.DURATION || "3m";
const readCreatorUsername = __ENV.READ_CREATOR_USERNAME || __ENV.CREATOR_USERNAME || "demo_creator";
const tippableUsername = __ENV.TIPPABLE_USERNAME || readCreatorUsername;
const tipAmountCents = Number(__ENV.TIP_AMOUNT_CENTS || 50000);

const readRate = Math.max(1, Math.round(readRpm / 60));
const writeRate = Math.max(1, Math.round(writeRpm / 60));

const defaultHeaders = {
  Accept: "application/json",
  Host: hostHeader,
};

const rateLimited = new Counter("rate_limited_429");
const hostBlocked = new Counter("host_blocked_403");
const serverErrors = new Counter("server_errors_5xx");
const successRate = new Rate("success_rate");
const profileLatency = new Trend("profile_latency", true);
const healthLatency = new Trend("health_latency", true);
const tipCreateLatency = new Trend("tip_create_latency", true);
const tipCheckoutLatency = new Trend("tip_checkout_latency", true);
const checkoutServerErrors = new Counter("checkout_server_errors_5xx");
const tipsCreated = new Counter("tips_created");
const tipsCheckoutPolled = new Counter("tips_checkout_polled");
const tipsReconciled = new Counter("tips_reconciled");

export const options = {
  scenarios: {
    public_reads: {
      executor: "constant-arrival-rate",
      exec: "publicRead",
      rate: readRate,
      timeUnit: "1s",
      duration,
      preAllocatedVUs: 250,
      maxVUs: 600,
    },
    tip_writes: {
      executor: "constant-arrival-rate",
      exec: "tipWrite",
      rate: writeRate,
      timeUnit: "1s",
      duration,
      preAllocatedVUs: 30,
      maxVUs: 120,
      startTime: "5s",
    },
  },
  thresholds: {
    http_req_failed: ["rate<0.50"],
    success_rate: ["rate>0.10"],
  },
};

function recordResponse(res, trend) {
  if (res.status === 429) {
    rateLimited.add(1);
    return;
  }

  if (res.status === 403) {
    hostBlocked.add(1);
    return;
  }

  if (res.status >= 500) {
    serverErrors.add(1);
    return;
  }

  if (trend) {
    trend.add(res.timings.duration);
  }

  if (res.status >= 200 && res.status < 400) {
    successRate.add(1);
  } else {
    successRate.add(0);
  }
}

export function publicRead() {
  const roll = Math.random();

  if (roll < 0.08) {
    const res = http.get(`${baseUrl}/up`, { tags: { endpoint: "health" }, headers: defaultHeaders });
    check(res, { "health ok": (r) => r.status === 200 });
    recordResponse(res, healthLatency);
    return;
  }

  if (roll < 0.15) {
    const res = http.get(`${baseUrl}/regions`, { tags: { endpoint: "regions" }, headers: defaultHeaders });
    check(res, { "regions ok": (r) => r.status === 200 });
    recordResponse(res, null);
    return;
  }

  const res = http.get(`${baseUrl}/tribes/${readCreatorUsername}`, {
    tags: { endpoint: "public_profile" },
    headers: defaultHeaders,
  });
  check(res, { "profile reachable": (r) => r.status === 200 || r.status === 429 });
  recordResponse(res, profileLatency);

  sleep(0.01);
}

export function tipWrite() {
  const unique = `${Date.now()}_${__VU}_${__ITER}`;
  const payload = JSON.stringify({
    tip: {
      username: tippableUsername,
      amount_cents: tipAmountCents,
      supporter_email: `loadtest+${unique}@tribetip.africa`,
      supporter_name: "Load Test",
      message: "k6 mixed write load test",
    },
  });

  const createRes = http.post(`${baseUrl}/tips`, payload, {
    tags: { endpoint: "tip_create" },
    headers: {
      ...defaultHeaders,
      "Content-Type": "application/json",
      "Idempotency-Key": `loadtest-${unique}`,
    },
  });

  check(createRes, {
    "tip create accepted": (r) => r.status === 201 || r.status === 202 || r.status === 429,
  });
  recordResponse(createRes, tipCreateLatency);

  if (createRes.status !== 201 && createRes.status !== 202) {
    return;
  }

  tipsCreated.add(1);

  let reference = null;
  try {
    reference = createRes.json("tip.paystack_reference");
  } catch (_error) {
    return;
  }

  if (!reference) {
    return;
  }

  const checkoutRes = http.get(`${baseUrl}/tips/checkout/${reference}`, {
    tags: { endpoint: "tip_checkout" },
    headers: defaultHeaders,
  });
  check(checkoutRes, {
    "checkout reachable": (r) => r.status === 200 || r.status === 429,
  });
  recordResponse(checkoutRes, tipCheckoutLatency);
  if (checkoutRes.status >= 500) {
    checkoutServerErrors.add(1);
  }
  tipsCheckoutPolled.add(1);

  const reconcileRes = http.post(`${baseUrl}/tips/${reference}/reconcile`, null, {
    tags: { endpoint: "tip_reconcile" },
    headers: defaultHeaders,
  });
  check(reconcileRes, {
    "reconcile reachable": (r) => (r.status >= 200 && r.status < 500) || r.status === 429,
  });
  recordResponse(reconcileRes, tipReconcileLatency);
  tipsReconciled.add(1);

  sleep(0.05);
}

export function handleSummary(data) {
  const lines = [
    "",
    "=== TribeTip mixed write load test summary ===",
    `Reads: ${readRpm} RPM (~${readRate}/s) | Writes: ${writeRpm} RPM (~${writeRate}/s) for ${duration}`,
    `Base URL: ${baseUrl} | Read profile: ${readCreatorUsername} | Tip target: ${tippableUsername}`,
    "",
    `HTTP failures: ${(data.metrics.http_req_failed?.values?.rate * 100 || 0).toFixed(2)}%`,
    `p95 latency: ${data.metrics.http_req_duration?.values?.["p(95)"]?.toFixed(2) || "n/a"} ms`,
    `429 rate-limited: ${data.metrics.rate_limited_429?.values?.count || 0}`,
    `403 host-blocked: ${data.metrics.host_blocked_403?.values?.count || 0}`,
    `5xx errors: ${data.metrics.server_errors_5xx?.values?.count || 0}`,
    `Checkout 5xx: ${data.metrics.checkout_server_errors_5xx?.values?.count || 0}`,
    `Tips created: ${data.metrics.tips_created?.values?.count || 0}`,
    `Checkout polls: ${data.metrics.tips_checkout_polled?.values?.count || 0}`,
    `Reconcile calls: ${data.metrics.tips_reconciled?.values?.count || 0}`,
    `Success rate (2xx/3xx): ${((data.metrics.success_rate?.values?.rate || 0) * 100).toFixed(2)}%`,
    "",
    "Note: reconcile may leave tips pending unless Paystack reports success.",
    "",
  ];

  return {
    stdout: lines.join("\n"),
    "/results/summary-write.json": JSON.stringify(data, null, 2),
  };
}

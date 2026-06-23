import http from "k6/http";
import { check, sleep } from "k6";
import { Counter, Rate, Trend } from "k6/metrics";

const baseUrl = __ENV.BASE_URL || "http://api:80";
const hostHeader = __ENV.HOST_HEADER || "localhost";
const targetRpm = Number(__ENV.TARGET_RPM || 10000);
const duration = __ENV.DURATION || "3m";
const creatorUsername = __ENV.CREATOR_USERNAME || "demo_creator";

// ~10k requests per minute ≈ 167 requests/second
const arrivalRate = Math.max(1, Math.round(targetRpm / 60));

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

export const options = {
  scenarios: {
    mixed_public_traffic: {
      executor: "constant-arrival-rate",
      rate: arrivalRate,
      timeUnit: "1s",
      duration,
      preAllocatedVUs: 250,
      maxVUs: 600,
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

export default function () {
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

  const res = http.get(`${baseUrl}/tribes/${creatorUsername}`, {
    tags: { endpoint: "public_profile" },
    headers: defaultHeaders,
  });
  check(res, { "profile reachable": (r) => r.status === 200 || r.status === 429 });
  recordResponse(res, profileLatency);

  sleep(0.01);
}

export function handleSummary(data) {
  const lines = [
    "",
    "=== TribeTip load test summary ===",
    `Target: ${targetRpm} RPM (~${arrivalRate}/s) for ${duration}`,
    `Base URL: ${baseUrl}`,
    "",
    `HTTP failures: ${(data.metrics.http_req_failed?.values?.rate * 100 || 0).toFixed(2)}%`,
    `p95 latency: ${data.metrics.http_req_duration?.values?.["p(95)"]?.toFixed(2) || "n/a"} ms`,
    `429 rate-limited: ${data.metrics.rate_limited_429?.values?.count || 0}`,
    `403 host-blocked: ${data.metrics.host_blocked_403?.values?.count || 0}`,
    `5xx errors: ${data.metrics.server_errors_5xx?.values?.count || 0}`,
    `Success rate (2xx/3xx): ${((data.metrics.success_rate?.values?.rate || 0) * 100).toFixed(2)}%`,
    "",
    "Watch for: per-IP Rack::Attack caps, DB pool exhaustion, Solid Cache pressure, worker backlog.",
    "",
  ];

  return {
    stdout: lines.join("\n"),
    "/results/summary.json": JSON.stringify(data, null, 2),
  };
}

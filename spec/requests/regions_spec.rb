# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Regions", type: :request do
  before do
    allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))
    Tribetip::Regions.reset!
  end

  after do
    Tribetip::Regions.reset!
  end

  it "returns launch flags for each market" do
    get "/regions"

    expect(response).to have_http_status(:ok)
    expect(json["default_country_code"]).to eq("KE")

    kenya = json.fetch("regions").find { |region| region["code"] == "KE" }
    nigeria = json.fetch("regions").find { |region| region["code"] == "NG" }

    expect(kenya).to include("enabled" => true, "currency" => "KES")
    expect(nigeria).to include("enabled" => false, "currency" => "NGN")
  end
end

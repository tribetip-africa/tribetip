# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::Platform do
  def with_env(vars)
    previous = vars.keys.index_with { |key| ENV[key] }
    vars.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
    yield
  ensure
    previous.each { |key, value| value.nil? ? ENV.delete(key) : ENV[key] = value }
  end

  describe ".app_url" do
    it "uses localhost in development" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      with_env("TRIBETIP_PLATFORM_URL" => nil) do
        expect(described_class.app_url).to eq("http://localhost:3000")
      end
    end

    it "uses tribetip.africa in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      with_env("TRIBETIP_PLATFORM_URL" => nil) do
        expect(described_class.app_url).to eq("https://tribetip.africa")
      end
    end

    it "respects TRIBETIP_PLATFORM_URL override" do
      with_env("TRIBETIP_PLATFORM_URL" => "https://dev.tribetip.africa/") do
        expect(described_class.app_url).to eq("https://dev.tribetip.africa")
      end
    end
  end

  describe ".api_url" do
    it "uses localhost API in development" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      with_env("TRIBETIP_API_URL" => nil) do
        expect(described_class.api_url).to eq("http://localhost:3001")
      end
    end

    it "uses api.tribetip.africa in production" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("production"))

      with_env("TRIBETIP_API_URL" => nil) do
        expect(described_class.api_url).to eq("https://api.tribetip.africa")
      end
    end
  end

  describe ".creator_page_url" do
    it "builds a creator page URL from the platform host" do
      expect(described_class.creator_page_url("ama_creates")).to eq("http://localhost:3000/ama_creates")
    end
  end

  describe ".cors_origins" do
    it "defaults to platform origins in development when unset" do
      allow(Rails).to receive(:env).and_return(ActiveSupport::StringInquirer.new("development"))

      with_env("CORS_ALLOWED_ORIGINS" => nil, "TRIBETIP_PLATFORM_URL" => nil) do
        expect(described_class.cors_origins).to contain_exactly(
          "http://localhost:3000",
          "http://127.0.0.1:3000"
        )
      end
    end
  end
end

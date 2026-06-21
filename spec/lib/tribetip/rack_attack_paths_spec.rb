# frozen_string_literal: true

require "rails_helper"

RSpec.describe Tribetip::RackAttackPaths do
  describe ".normalize" do
    it "strips json and xml format suffixes" do
      expect(described_class.normalize("/tribes/sign_in.json")).to eq("/tribes/sign_in")
      expect(described_class.normalize("/tribes/sign_in.xml")).to eq("/tribes/sign_in")
      expect(described_class.normalize("/tribes/sign_in")).to eq("/tribes/sign_in")
    end
  end

  describe ".auth_path?" do
    def request(method:, path:)
      instance_double(ActionDispatch::Request, post?: method == :post, path: path)
    end

    it "matches auth routes with format suffixes" do
      expect(described_class.auth_path?(request(method: :post, path: "/tribes/sign_in.json"))).to be(true)
      expect(described_class.auth_path?(request(method: :post, path: "/tribes.json"))).to be(true)
      expect(described_class.auth_path?(request(method: :post, path: "/tribes/password.json"))).to be(true)
    end

    it "ignores non-auth routes and non-post requests" do
      expect(described_class.auth_path?(request(method: :get, path: "/tribes/sign_in.json"))).to be(false)
      expect(described_class.auth_path?(request(method: :post, path: "/tips"))).to be(false)
    end
  end

  describe ".public_profile_path?" do
    def request(method:, path:)
      instance_double(ActionDispatch::Request, get?: method == :get, path: path)
    end

    it "matches public creator profile routes" do
      expect(described_class.public_profile_path?(request(method: :get, path: "/tribes/ama_creates"))).to be(true)
      expect(described_class.public_profile_path?(request(method: :post, path: "/tribes/ama_creates"))).to be(false)
    end
  end

  describe ".share_profile_path?" do
    def request(method:, path:)
      instance_double(ActionDispatch::Request, get?: method == :get, path: path)
    end

    it "matches opaque share profile routes" do
      token = "abc123-_ABCdef456789012345678"
      expect(described_class.share_profile_path?(request(method: :get, path: "/share/#{token}"))).to be(true)
    end
  end

  describe ".widget_config_path?" do
    def request(method:, path:)
      instance_double(ActionDispatch::Request, get?: method == :get, path: path)
    end

    it "matches the widget config route" do
      expect(described_class.widget_config_path?(request(method: :get, path: "/widget/config"))).to be(true)
    end
  end
end

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
end

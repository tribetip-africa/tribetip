# frozen_string_literal: true

require "rails_helper"

RSpec.describe DatabaseRouting, type: :controller do
  controller(ApplicationController) do
    def index
      head :ok
    end
  end

  before do
    routes.draw { get "index" => "anonymous#index" }
  end

  describe "#force_primary_connection?" do
    it "routes public checkout polling to the primary" do
      allow(controller).to receive(:request).and_return(
        instance_double(
          ActionDispatch::Request,
          path: "/tips/checkout/tip_abc123",
          get?: true,
          post?: false,
          put?: false,
          patch?: false,
          delete?: false,
          headers: {}
        )
      )

      expect(controller.send(:force_primary_connection?)).to be(true)
    end

    it "keeps public profile reads on the replica path" do
      allow(controller).to receive(:request).and_return(
        instance_double(
          ActionDispatch::Request,
          path: "/tribes/demo_creator",
          get?: true,
          post?: false,
          put?: false,
          patch?: false,
          delete?: false,
          headers: {}
        )
      )

      expect(controller.send(:force_primary_connection?)).to be(false)
    end
  end
end

# frozen_string_literal: true

module RequestSpecHelpers
  def json
    JSON.parse(response.body)
  end

  def bearer_token_for(tribe)
    token, = Warden::JWTAuth::UserEncoder.new.call(tribe, :tribe, nil)
    { "Authorization" => "Bearer #{token}" }
  end
end

RSpec.configure do |config|
  config.include RequestSpecHelpers, type: :request
end

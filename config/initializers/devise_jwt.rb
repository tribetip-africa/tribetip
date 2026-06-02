Devise.setup do |config|
  config.jwt do |jwt|
    jwt.secret = ENV.fetch("DEVISE_JWT_SECRET_KEY") do
      Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base
    end
    jwt.dispatch_requests = [
      [ "POST", %r{^/tribes/sign_in} ]
    ]
    jwt.revocation_requests = [
      [ "DELETE", %r{^/tribes/sign_out} ]
    ]
    jwt.expiration_time = 1.day.to_i
  end
end

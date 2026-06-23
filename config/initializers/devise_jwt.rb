Devise.setup do |config|
  config.jwt do |jwt|
    jwt.secret = if Rails.env.production?
      ENV.fetch("DEVISE_JWT_SECRET_KEY")
    else
      ENV.fetch("DEVISE_JWT_SECRET_KEY") do
        Rails.application.credentials.devise_jwt_secret_key || Rails.application.secret_key_base
      end
    end
    jwt.dispatch_requests = [
      [ "POST", %r{^/tribes/sign_in} ]
    ]
    jwt.revocation_requests = [
      [ "DELETE", %r{^/tribes/sign_out} ]
    ]
    jwt.expiration_time = ENV.fetch("DEVISE_JWT_EXPIRATION_SECONDS", 4.hours.to_i).to_i
  end
end

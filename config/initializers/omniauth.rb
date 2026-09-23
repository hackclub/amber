Rails.application.config.middleware.use OmniAuth::Builder do
  if !Rails.env.production? && ENV["HACKCLUB_AUTH_CLIENT_ID"].blank?
    # Lets you build and test the app (development and test envs) before
    # registering a real app at https://auth.hackclub.com/developer/apps.
    # Visits /auth/developer to sign in as any name/email you type, with no
    # external calls. Never used in production.
    provider :developer
  else
    provider :openid_connect, {
      name: :hackclub,
      issuer: "https://auth.hackclub.com",
      discovery: true,
      scope: [ :openid, :email, :profile, :slack_id ],
      response_type: :code,
      uid_field: "sub",
      client_options: {
        identifier: ENV["HACKCLUB_AUTH_CLIENT_ID"],
        secret: ENV["HACKCLUB_AUTH_CLIENT_SECRET"],
        redirect_uri: ENV["HACKCLUB_AUTH_REDIRECT_URI"]
      }
    }
  end
end

OmniAuth.config.allowed_request_methods = [ :post ]
OmniAuth.config.silence_get_warning = true

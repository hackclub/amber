# Dynamic client registration (RFC 7591), so a connector can register itself
# instead of someone hand-copying credentials around.
module Oauth
  class ClientsController < ActionController::Base
    skip_forgery_protection

    rate_limit to: 20, within: 1.hour, by: -> { request.remote_ip }

    def create
      body = JSON.parse(request.raw_post)
      # A client asking for client_secret_post/basic wants a secret; everything
      # else is treated as a public client authenticating with PKCE alone.
      public_client = body["token_endpoint_auth_method"].blank? || body["token_endpoint_auth_method"] == "none"

      client, secret = OauthClient.register!(
        name: body["client_name"],
        redirect_uris: body["redirect_uris"],
        public_client: public_client
      )

      render json: {
        client_id: client.client_id,
        client_secret: secret,
        client_id_issued_at: client.created_at.to_i,
        client_name: client.name,
        redirect_uris: client.redirect_uris,
        grant_types: [ "authorization_code", "refresh_token" ],
        response_types: [ "code" ],
        token_endpoint_auth_method: public_client ? "none" : "client_secret_post"
      }.compact, status: :created
    rescue JSON::ParserError
      render json: { error: "invalid_client_metadata", error_description: "Body must be JSON" }, status: :bad_request
    rescue ActiveRecord::RecordInvalid => e
      render json: { error: "invalid_redirect_uri", error_description: e.record.errors.full_messages.to_sentence },
             status: :bad_request
    end
  end
end

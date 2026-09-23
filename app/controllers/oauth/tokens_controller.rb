module Oauth
  class TokensController < ActionController::Base
    skip_forgery_protection

    rate_limit to: 60, within: 1.minute, by: -> { request.remote_ip }, only: :create

    def create
      case params[:grant_type]
      when "authorization_code" then exchange_code
      when "refresh_token" then refresh
      else render_error("unsupported_grant_type", "Use authorization_code or refresh_token")
      end
    end

    def revoke
      token = OauthToken.authenticate(params[:token]) || OauthToken.find_by_refresh_token(params[:token])
      token&.revoke!

      # RFC 7009: revoking an unknown token is still a success.
      head :ok
    end

    private

    def exchange_code
      client = authenticate_client
      return if performed?

      grant = OauthGrant.redeem!(
        code: params[:code],
        client: client,
        redirect_uri: params[:redirect_uri],
        code_verifier: params[:code_verifier]
      )

      return render_error("invalid_grant", "That code is expired, already used, or doesn't match") if grant.nil?

      _token, access, refresh = OauthToken.issue!(client: client, user: grant.user, scope: grant.scope)
      render_token(access, refresh, OauthToken::ACCESS_TOKEN_LIFETIME.to_i, grant.scope)
    end

    def refresh
      client = authenticate_client
      return if performed?

      token = OauthToken.find_by_refresh_token(params[:refresh_token])
      return render_error("invalid_grant", "Unknown or revoked refresh token") if token.nil? || token.oauth_client_id != client.id

      access = token.refresh!
      render_token(access, params[:refresh_token], token.expires_in, token.scope)
    end

    def authenticate_client
      client_id, client_secret = credentials
      client = OauthClient.find_by(client_id: client_id)

      return render_error("invalid_client", "Unknown client") && nil if client.nil?
      return render_error("invalid_client", "Bad client credentials") && nil unless client.authenticates_with?(client_secret)

      client
    end

    # Clients may authenticate with HTTP Basic or by posting the credentials.
    def credentials
      basic = ActionController::HttpAuthentication::Basic.decode_credentials(request).split(":", 2)
      return basic.map { |part| CGI.unescape(part) } if basic.length == 2 && basic.first.present?

      [ params[:client_id], params[:client_secret] ]
    end

    def render_token(access_token, refresh_token, expires_in, scope)
      render json: {
        access_token: access_token,
        token_type: "Bearer",
        expires_in: expires_in,
        refresh_token: refresh_token,
        scope: scope
      }
    end

    def render_error(error, description)
      render json: { error: error, error_description: description }, status: :bad_request
      true
    end
  end
end

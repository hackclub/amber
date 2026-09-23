module Oauth
  # The consent step. Inherits ApplicationController so it reuses the ordinary
  # Hack Club Auth session — signing in here is just signing into the app.
  class AuthorizationsController < ApplicationController
    before_action :load_client
    before_action :validate_request!

    def new
      @authorization = authorization_params
    end

    def create
      return redirect_with_error("access_denied", "You declined access") if params[:commit] == "Deny"

      code = OauthGrant.issue!(
        client: @client,
        user: current_user,
        redirect_uri: params[:redirect_uri],
        code_challenge: params[:code_challenge],
        scope: OauthConfig::SCOPE,
        resource: params[:resource]
      )

      redirect_to_client(code: code, state: params[:state])
    end

    private

    def load_client
      @client = OauthClient.find_by(client_id: params[:client_id])

      # Before the redirect URI is known-good, errors have to be shown here
      # rather than bounced to a URI an attacker could have supplied.
      return render_error("Unknown client. Try removing and re-adding the connector.") if @client.nil?
      render_error("That redirect URL isn't registered for this client.") unless @client.allows?(params[:redirect_uri])
    end

    def validate_request!
      return redirect_with_error("unsupported_response_type", "Only the authorization code flow is supported") unless params[:response_type] == "code"
      redirect_with_error("invalid_request", "PKCE with S256 is required") unless params[:code_challenge].present? && params[:code_challenge_method] == "S256"
    end

    def authorization_params
      params.permit(:client_id, :redirect_uri, :response_type, :state, :scope, :resource,
                    :code_challenge, :code_challenge_method)
    end

    def redirect_to_client(**query)
      uri = URI.parse(params[:redirect_uri])
      existing = URI.decode_www_form(uri.query.to_s)
      uri.query = URI.encode_www_form(existing + query.compact.transform_keys(&:to_s).to_a)

      redirect_to uri.to_s, allow_other_host: true
    end

    def redirect_with_error(error, description)
      redirect_to_client(error: error, error_description: description, state: params[:state])
    end

    def render_error(message)
      render "oauth/authorizations/error", locals: { message: message }, status: :bad_request
    end
  end
end

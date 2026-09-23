# Discovery documents an MCP client fetches before it can authenticate:
# RFC 9728 for the resource, RFC 8414 for the authorization server.
class WellKnownController < ActionController::Base
  def protected_resource
    render json: {
      resource: mcp_url,
      authorization_servers: [ issuer ],
      scopes_supported: [ OauthConfig::SCOPE ],
      bearer_methods_supported: [ "header" ],
      resource_documentation: root_url
    }
  end

  def authorization_server
    render json: {
      issuer: issuer,
      authorization_endpoint: oauth_authorize_url,
      token_endpoint: oauth_token_url,
      registration_endpoint: oauth_register_url,
      revocation_endpoint: oauth_revoke_url,
      scopes_supported: [ OauthConfig::SCOPE ],
      response_types_supported: [ "code" ],
      grant_types_supported: [ "authorization_code", "refresh_token" ],
      code_challenge_methods_supported: [ "S256" ],
      token_endpoint_auth_methods_supported: [ "none", "client_secret_post", "client_secret_basic" ]
    }
  end

  private

  def issuer
    root_url.chomp("/")
  end
end

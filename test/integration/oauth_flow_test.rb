require "test_helper"

# The whole dance a connector does: discover, register, approve, exchange,
# call the MCP endpoint, refresh, revoke.
class OauthFlowTest < ActionDispatch::IntegrationTest
  VERIFIER = "a-verifier-long-enough-to-be-valid-0123456789".freeze

  def challenge
    Base64.urlsafe_encode64(OpenSSL::Digest::SHA256.digest(VERIFIER), padding: false)
  end

  def sign_in(user)
    get "/auth/developer/callback", params: { name: user.name, email: user.email }
  end

  def register_client(redirect_uris: [ "https://claude.ai/api/mcp/auth_callback" ], auth_method: nil)
    post oauth_register_path,
         params: { client_name: "Claude", redirect_uris: redirect_uris, token_endpoint_auth_method: auth_method }.compact.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }
    response.parsed_body
  end

  test "discovery points at this server as its own authorization server" do
    get "/.well-known/oauth-protected-resource"

    assert_response :success
    body = response.parsed_body
    assert_equal "http://www.example.com/mcp", body["resource"]
    assert_equal [ "http://www.example.com" ], body["authorization_servers"]
  end

  test "authorization server metadata advertises PKCE and registration" do
    get "/.well-known/oauth-authorization-server"

    assert_response :success
    body = response.parsed_body
    assert_equal [ "S256" ], body["code_challenge_methods_supported"]
    assert_equal "http://www.example.com/oauth/register", body["registration_endpoint"]
    assert_includes body["grant_types_supported"], "refresh_token"
  end

  test "an unauthenticated MCP call points the client at discovery" do
    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :unauthorized
    assert_match "resource_metadata=", response.headers["WWW-Authenticate"]
  end

  test "a client can register itself" do
    body = register_client

    assert_response :created
    assert body["client_id"].present?
    assert_nil body["client_secret"], "public clients shouldn't get a secret"
    assert_equal "none", body["token_endpoint_auth_method"]
  end

  test "registration rejects a non-https redirect" do
    register_client(redirect_uris: [ "http://evil.example.com/callback" ])

    assert_response :bad_request
    assert_equal "invalid_redirect_uri", response.parsed_body["error"]
  end

  test "the full authorization code flow gets a working access token" do
    client = register_client
    sign_in(users(:requester))

    get oauth_authorize_path, params: authorize_params(client)
    assert_response :success
    assert_select "h1", /wants access/

    post oauth_authorize_path, params: authorize_params(client).merge(commit: "Approve")
    assert_response :redirect

    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    assert code.present?
    assert_equal "xyz", Rack::Utils.parse_query(URI.parse(response.location).query)["state"]

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: client["client_id"],
      redirect_uri: client["redirect_uris"].first, code_verifier: VERIFIER
    }
    assert_response :success

    tokens = response.parsed_body
    assert_equal "Bearer", tokens["token_type"]

    # The access token works on the MCP endpoint, as the user who approved it.
    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{tokens['access_token']}" }

    assert_response :success
    names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }
    assert_includes names, "create_ticket"
    refute_includes names, "my_queue", "a requester's token must not unlock admin tools"
  end

  test "an admin's token unlocks the admin tools" do
    client = register_client
    sign_in(users(:amber))
    access_token = approve_and_exchange(client)

    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "tools/list" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{access_token}" }

    names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }
    assert_includes names, "my_queue"
  end

  test "a code can't be redeemed twice" do
    client = register_client
    sign_in(users(:requester))
    post oauth_authorize_path, params: authorize_params(client).merge(commit: "Approve")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    exchange = lambda do
      post oauth_token_path, params: {
        grant_type: "authorization_code", code: code, client_id: client["client_id"],
        redirect_uri: client["redirect_uris"].first, code_verifier: VERIFIER
      }
    end

    exchange.call
    assert_response :success

    exchange.call
    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "the wrong PKCE verifier is refused" do
    client = register_client
    sign_in(users(:requester))
    post oauth_authorize_path, params: authorize_params(client).merge(commit: "Approve")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: client["client_id"],
      redirect_uri: client["redirect_uris"].first, code_verifier: "not-the-verifier-we-started-with"
    }

    assert_response :bad_request
    assert_equal "invalid_grant", response.parsed_body["error"]
  end

  test "an unregistered redirect uri never redirects" do
    client = register_client
    sign_in(users(:requester))

    get oauth_authorize_path, params: authorize_params(client).merge(redirect_uri: "https://evil.example.com/steal")

    assert_response :bad_request
    assert_match "registered for this client", response.body
  end

  test "authorization requires PKCE" do
    client = register_client
    sign_in(users(:requester))

    get oauth_authorize_path, params: authorize_params(client).except(:code_challenge, :code_challenge_method)

    assert_response :redirect
    assert_equal "invalid_request", Rack::Utils.parse_query(URI.parse(response.location).query)["error"]
  end

  test "denying sends back an error instead of a code" do
    client = register_client
    sign_in(users(:requester))

    post oauth_authorize_path, params: authorize_params(client).merge(commit: "Deny")

    query = Rack::Utils.parse_query(URI.parse(response.location).query)
    assert_equal "access_denied", query["error"]
    assert_nil query["code"]
  end

  test "signing in mid-flow returns you to the consent screen" do
    client = register_client

    get oauth_authorize_path, params: authorize_params(client)
    assert_redirected_to root_path

    sign_in(users(:requester))
    landed = URI.parse(response.location)
    assert_equal oauth_authorize_path, landed.path
    assert_equal authorize_params(client).stringify_keys, Rack::Utils.parse_query(landed.query)
  end

  test "a refresh token mints a new access token" do
    client = register_client
    sign_in(users(:requester))
    post oauth_authorize_path, params: authorize_params(client).merge(commit: "Approve")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]
    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: client["client_id"],
      redirect_uri: client["redirect_uris"].first, code_verifier: VERIFIER
    }
    first = response.parsed_body

    post oauth_token_path, params: {
      grant_type: "refresh_token", refresh_token: first["refresh_token"], client_id: client["client_id"]
    }

    assert_response :success
    refute_equal first["access_token"], response.parsed_body["access_token"]

    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json",
                    "Authorization" => "Bearer #{response.parsed_body['access_token']}" }
    assert_response :success
  end

  test "disconnecting an app from settings kills its token" do
    client = register_client
    sign_in(users(:requester))
    access_token = approve_and_exchange(client)

    get settings_path
    assert_match "Claude", response.body

    delete connection_settings_path(OauthToken.last)
    assert_redirected_to settings_path

    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{access_token}" }
    assert_response :unauthorized
  end

  test "revoking at the endpoint kills the token too" do
    client = register_client
    sign_in(users(:requester))
    access_token = approve_and_exchange(client)

    post oauth_revoke_path, params: { token: access_token }
    assert_response :ok

    post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json,
         headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{access_token}" }
    assert_response :unauthorized
  end

  test "an expired access token stops working" do
    client = register_client
    sign_in(users(:requester))
    access_token = approve_and_exchange(client)

    travel(OauthToken::ACCESS_TOKEN_LIFETIME + 1.minute) do
      post mcp_path, params: { jsonrpc: "2.0", id: 1, method: "ping" }.to_json,
           headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{access_token}" }
      assert_response :unauthorized
    end
  end

  private

  def authorize_params(client)
    {
      response_type: "code",
      client_id: client["client_id"],
      redirect_uri: client["redirect_uris"].first,
      code_challenge: challenge,
      code_challenge_method: "S256",
      state: "xyz",
      scope: "mcp"
    }
  end

  def approve_and_exchange(client)
    post oauth_authorize_path, params: authorize_params(client).merge(commit: "Approve")
    code = Rack::Utils.parse_query(URI.parse(response.location).query)["code"]

    post oauth_token_path, params: {
      grant_type: "authorization_code", code: code, client_id: client["client_id"],
      redirect_uri: client["redirect_uris"].first, code_verifier: VERIFIER
    }

    response.parsed_body["access_token"]
  end
end

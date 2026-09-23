# Model Context Protocol endpoint (Streamable HTTP transport). Authenticated
# with a personal API token rather than the browser session, so it doesn't
# inherit ApplicationController's login redirect.
class McpController < ActionController::Base
  skip_forgery_protection

  rate_limit to: 120, within: 1.minute, by: -> { request.authorization.to_s }, only: :create

  before_action :authenticate_api_token!

  def create
    payload = JSON.parse(request.raw_post)
    server = McpServer.new(@current_user)

    if payload.is_a?(Array)
      responses = payload.filter_map { |message| server.handle(message) }
      responses.any? ? render(json: responses) : head(:accepted)
    else
      response_body = server.handle(payload)
      response_body ? render(json: response_body) : head(:accepted)
    end
  rescue JSON::ParserError
    render json: { "jsonrpc" => "2.0", "id" => nil,
                   "error" => { "code" => McpServer::PARSE_ERROR, "message" => "Invalid JSON" } },
           status: :bad_request
  end

  # The server never initiates messages, so there's no stream to open.
  def unsupported
    head :method_not_allowed
  end

  private

  def authenticate_api_token!
    token = request.authorization.to_s[/\ABearer (.+)\z/i, 1]
    @current_user = User.authenticate_api_token(token)

    return if @current_user

    response.set_header("WWW-Authenticate", 'Bearer realm="tickets"')
    render json: { "jsonrpc" => "2.0", "id" => nil,
                   "error" => { "code" => McpServer::INVALID_REQUEST, "message" => "Invalid or missing API token" } },
           status: :unauthorized
  end
end

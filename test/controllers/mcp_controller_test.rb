require "test_helper"

class McpControllerTest < ActionDispatch::IntegrationTest
  setup do
    @requester = users(:requester)
    @requester_token = @requester.regenerate_api_token!
    @admin_token = users(:amber).regenerate_api_token!
  end

  test "rejects a request with no token" do
    post mcp_path, params: rpc("tools/list").to_json, headers: { "CONTENT_TYPE" => "application/json" }

    assert_response :unauthorized
    assert_match "Bearer", response.headers["WWW-Authenticate"]
  end

  test "rejects a bogus token" do
    mcp_call("tools/list", token: "tkt_nonsense")

    assert_response :unauthorized
  end

  test "initialize reports the protocol version the client asked for" do
    mcp_call("initialize", { "protocolVersion" => "2025-03-26" }, token: @requester_token)

    assert_response :success
    assert_equal "2025-03-26", response.parsed_body.dig("result", "protocolVersion")
    assert_equal "tickets", response.parsed_body.dig("result", "serverInfo", "name")
  end

  test "notifications get no response body" do
    mcp_call("notifications/initialized", token: @requester_token)

    assert_response :accepted
    assert_empty response.body
  end

  test "a requester sees only the non-admin tools" do
    mcp_call("tools/list", token: @requester_token)

    names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }
    assert_includes names, "create_ticket"
    assert_includes names, "list_my_tickets"
    refute_includes names, "my_queue"
    refute_includes names, "update_ticket_status"
  end

  test "an admin also sees the queue tools" do
    mcp_call("tools/list", token: @admin_token)

    names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }
    assert_includes names, "my_queue"
    assert_includes names, "update_ticket_status"
  end

  test "create_ticket files a ticket for the token's owner" do
    assert_difference -> { @requester.tickets.count }, 1 do
      call_tool("create_ticket", {
        "title" => "Signup 500s on mobile",
        "service" => "website",
        "topic" => "bug",
        "message" => "It fails on iOS Safari.",
        "priority" => "high"
      }, token: @requester_token)
    end

    assert_response :success
    refute response.parsed_body.dig("result", "isError")

    ticket = @requester.tickets.order(:created_at).last
    assert_equal "Signup 500s on mobile", ticket.title
    assert_equal "high", ticket.priority
    assert_equal services(:website), ticket.service
  end

  test "create_ticket with an unknown service returns a usable error" do
    assert_no_difference -> { Ticket.count } do
      call_tool("create_ticket", {
        "title" => "x", "service" => "Nope", "topic" => "Bug", "message" => "y"
      }, token: @requester_token)
    end

    assert response.parsed_body.dig("result", "isError")
    assert_match "Website", text_content
  end

  test "list_my_tickets only shows your own" do
    call_tool("list_my_tickets", {}, token: @requester_token)

    assert_match tickets(:website_bug).title, text_content
    assert_no_match(/#{other_persons_ticket.title}/, text_content)
  end

  test "get_ticket refuses someone else's ticket" do
    call_tool("get_ticket", { "id" => other_persons_ticket.id }, token: @requester_token)

    assert response.parsed_body.dig("result", "isError")
  end

  test "my_queue is refused for non-admins" do
    call_tool("my_queue", {}, token: @requester_token)

    assert response.parsed_body.dig("result", "isError")
    assert_match "Unknown tool", text_content
  end

  test "my_queue lists what is waiting on the admin" do
    call_tool("my_queue", {}, token: @admin_token)

    refute response.parsed_body.dig("result", "isError")
    assert_match tickets(:website_bug).title, text_content
  end

  test "update_ticket_status changes status and records the note" do
    ticket = tickets(:website_bug)

    call_tool("update_ticket_status", { "id" => ticket.id, "status" => "done", "note" => "Shipped." }, token: @admin_token)

    ticket.reload
    assert ticket.done?
    assert_equal "Shipped.", ticket.status_note
  end

  test "an invalid status is reported rather than crashing" do
    ticket = tickets(:website_bug)

    call_tool("update_ticket_status", { "id" => ticket.id, "status" => "wontfix" }, token: @admin_token)

    assert_response :success
    assert response.parsed_body.dig("result", "isError")
    assert_match "not_doing", text_content
    assert_equal "open", ticket.reload.status
  end

  test "a non-admin cannot update a status" do
    ticket = tickets(:website_bug)

    call_tool("update_ticket_status", { "id" => ticket.id, "status" => "done" }, token: @requester_token)

    refute ticket.reload.done?
  end

  test "an admin can create a service with topics" do
    assert_difference -> { Service.count }, 1 do
      call_tool("create_service", { "name" => "Hardware", "topics" => [ "Laptop", "Printer" ] }, token: @admin_token)
    end

    service = Service.find_by(name: "Hardware")
    assert_equal [ "Laptop", "Printer" ], service.topics.order(:name).pluck(:name)
  end

  test "an admin can retire a service without touching its tickets" do
    call_tool("update_service", { "name" => "Website", "active" => false }, token: @admin_token)

    refute services(:website).reload.active?
    assert tickets(:website_bug).reload.persisted?
  end

  test "an admin can rename a topic" do
    call_tool("update_topic", { "service" => "Website", "name" => "Bug", "new_name" => "Defect" }, token: @admin_token)

    assert_equal "Defect", topics(:bug).reload.name
  end

  test "taxonomy tools are hidden from non-admins" do
    mcp_call("tools/list", token: @requester_token)
    names = response.parsed_body.dig("result", "tools").map { |tool| tool["name"] }

    refute_includes names, "create_service"
    refute_includes names, "update_topic"
  end

  test "a non-admin cannot create a service" do
    assert_no_difference -> { Service.count } do
      call_tool("create_service", { "name" => "Sneaky" }, token: @requester_token)
    end

    assert response.parsed_body.dig("result", "isError")
  end

  test "retired services stay visible to admins and hidden from requesters" do
    services(:slack).update!(active: false)

    call_tool("list_services", {}, token: @admin_token)
    assert_match "Slack (retired)", text_content

    call_tool("list_services", {}, token: @requester_token)
    assert_no_match(/Slack/, text_content)
  end

  test "an admin can add an internal note" do
    ticket = tickets(:website_bug)

    assert_difference -> { ticket.notes.count }, 1 do
      call_tool("add_internal_note", { "id" => ticket.id, "note" => "Waiting on a reply from ops." }, token: @admin_token)
    end

    refute response.parsed_body.dig("result", "isError")
    assert_equal users(:amber), ticket.notes.last.author
  end

  test "notes append rather than overwrite" do
    ticket = tickets(:website_bug)

    call_tool("add_internal_note", { "id" => ticket.id, "note" => "first" }, token: @admin_token)
    call_tool("add_internal_note", { "id" => ticket.id, "note" => "second" }, token: @admin_token)

    assert_equal [ "first", "second" ], ticket.notes.oldest_first.pluck(:body)
  end

  test "internal notes are hidden from the requester's own ticket" do
    ticket = tickets(:website_bug)
    ticket.notes.create!(body: "Do not show this to them", author: users(:amber))

    call_tool("get_ticket", { "id" => ticket.id }, token: @requester_token)

    assert_no_match(/Do not show this to them/, text_content)
    assert_no_match(/Internal notes/, text_content)
  end

  test "an admin sees internal notes on a ticket" do
    ticket = tickets(:website_bug)
    ticket.notes.create!(body: "Chased this up on Tuesday", author: users(:amber))

    call_tool("get_ticket", { "id" => ticket.id }, token: @admin_token)

    assert_match "Chased this up on Tuesday", text_content
    assert_match "Internal notes", text_content
  end

  test "a non-admin can't add an internal note" do
    ticket = tickets(:website_bug)

    assert_no_difference -> { ticket.notes.count } do
      call_tool("add_internal_note", { "id" => ticket.id, "note" => "sneaky" }, token: @requester_token)
    end

    assert response.parsed_body.dig("result", "isError")
  end

  test "GET is not supported" do
    get mcp_path, headers: { "Authorization" => "Bearer #{@requester_token}" }

    assert_response :method_not_allowed
  end

  private

  def other_persons_ticket
    @other_persons_ticket ||= users(:amber).tickets.create!(
      title: "Amber's own ticket", message: "mine", service: services(:slack), topic: topics(:access_request)
    )
  end

  def rpc(method, params = {}, id: 1)
    { "jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params }
  end

  def mcp_call(method, params = {}, token:)
    post mcp_path, params: rpc(method, params).to_json,
         headers: { "CONTENT_TYPE" => "application/json", "Authorization" => "Bearer #{token}" }
  end

  def call_tool(name, arguments, token:)
    mcp_call("tools/call", { "name" => name, "arguments" => arguments }, token: token)
  end

  def text_content
    response.parsed_body.dig("result", "content").map { |part| part["text"] }.join("\n")
  end
end

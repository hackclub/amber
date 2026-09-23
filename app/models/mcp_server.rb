# A Model Context Protocol server over JSON-RPC, so tickets can be filed and
# triaged from inside an AI client. Every call is scoped to the user whose API
# token authenticated the request; admin-only tools are hidden from everyone else.
class McpServer
  PROTOCOL_VERSION = "2025-06-18".freeze
  SUPPORTED_PROTOCOL_VERSIONS = [ PROTOCOL_VERSION, "2025-03-26", "2024-11-05" ].freeze

  PARSE_ERROR = -32700
  INVALID_REQUEST = -32600
  METHOD_NOT_FOUND = -32601
  INVALID_PARAMS = -32602
  INTERNAL_ERROR = -32603

  def initialize(user)
    @user = user
  end

  # Returns a JSON-RPC response hash, or nil for notifications (which get no reply).
  def handle(message)
    return error(nil, INVALID_REQUEST, "Invalid request") unless message.is_a?(Hash)

    id = message["id"]
    params = message["params"] || {}

    case message["method"]
    when "initialize" then success(id, initialize_result(params))
    when "ping" then success(id, {})
    when "tools/list" then success(id, { "tools" => tools })
    when "tools/call" then success(id, call_tool(params))
    when /\Anotifications\// then nil
    else
      id.nil? ? nil : error(id, METHOD_NOT_FOUND, "Unknown method: #{message['method']}")
    end
  rescue ActiveRecord::RecordNotFound
    error(id, INVALID_PARAMS, "No such ticket")
  rescue StandardError => e
    Rails.logger.error("MCP error: #{e.class}: #{e.message}")
    error(id, INTERNAL_ERROR, e.message)
  end

  private

  attr_reader :user

  def initialize_result(params)
    requested = params["protocolVersion"]

    {
      "protocolVersion" => SUPPORTED_PROTOCOL_VERSIONS.include?(requested) ? requested : PROTOCOL_VERSION,
      "capabilities" => { "tools" => { "listChanged" => false } },
      "serverInfo" => { "name" => "tickets", "version" => AppRevision.sha },
      "instructions" => "Tickets for #{ENV.fetch('APP_HOST', 'this app')}. " \
                        "Call list_services before create_ticket so you use a real service and topic."
    }
  end

  def tools
    list = [
      {
        "name" => "list_services",
        "description" => "List the services and their topics that a ticket can be filed under. " \
                         "Call this before create_ticket.",
        "inputSchema" => { "type" => "object", "properties" => {} }
      },
      {
        "name" => "create_ticket",
        "description" => "File a new ticket. Service and topic must come from list_services.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "title" => { "type" => "string", "description" => "Short summary of the request" },
            "service" => { "type" => "string", "description" => "Service name, e.g. Website" },
            "topic" => { "type" => "string", "description" => "Topic name within that service, e.g. Bug" },
            "message" => { "type" => "string", "description" => "The details. Markdown is supported." },
            "priority" => { "type" => "string", "enum" => Ticket.priorities.keys, "description" => "Defaults to medium" },
            "url" => { "type" => "string", "description" => "Optional link to something relevant" }
          },
          "required" => [ "title", "service", "topic", "message" ]
        }
      },
      {
        "name" => "list_my_tickets",
        "description" => "List tickets you filed, newest first.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "status" => { "type" => "string", "enum" => Ticket.statuses.keys + [ "all" ], "description" => "Defaults to all" }
          }
        }
      },
      {
        "name" => "get_ticket",
        "description" => "Get the full details of one ticket, including its latest status note.",
        "inputSchema" => {
          "type" => "object",
          "properties" => { "id" => { "type" => "integer" } },
          "required" => [ "id" ]
        }
      }
    ]

    list + (user.admin? ? admin_tools : [])
  end

  def admin_tools
    [
      {
        "name" => "my_queue",
        "description" => "Everything waiting on you: open and in-progress tickets across all requesters, " \
                         "ordered with VIP requesters and higher priority first.",
        "inputSchema" => {
          "type" => "object",
          "properties" => { "limit" => { "type" => "integer", "description" => "Defaults to 25" } }
        }
      },
      {
        "name" => "update_ticket_status",
        "description" => "Change a ticket's status. The optional note is emailed and DM'd to the requester.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "id" => { "type" => "integer" },
            "status" => { "type" => "string", "enum" => Ticket.statuses.keys },
            "note" => { "type" => "string", "description" => "Optional explanation sent to the requester" }
          },
          "required" => [ "id", "status" ]
        }
      },
      {
        "name" => "create_service",
        "description" => "Add a service that tickets can be filed under, optionally with its first topics.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string" },
            "topics" => { "type" => "array", "items" => { "type" => "string" }, "description" => "Optional topic names to create under it" }
          },
          "required" => [ "name" ]
        }
      },
      {
        "name" => "update_service",
        "description" => "Rename a service, or retire it by setting active to false — retiring hides it from the " \
                         "new-ticket form while keeping existing tickets intact. Deleting is web-only, on purpose.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "name" => { "type" => "string", "description" => "The service to change" },
            "new_name" => { "type" => "string" },
            "active" => { "type" => "boolean" }
          },
          "required" => [ "name" ]
        }
      },
      {
        "name" => "create_topic",
        "description" => "Add a topic under an existing service.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "service" => { "type" => "string" },
            "name" => { "type" => "string" }
          },
          "required" => [ "service", "name" ]
        }
      },
      {
        "name" => "update_topic",
        "description" => "Rename a topic, or retire it by setting active to false. Deleting is web-only, on purpose.",
        "inputSchema" => {
          "type" => "object",
          "properties" => {
            "service" => { "type" => "string" },
            "name" => { "type" => "string", "description" => "The topic to change" },
            "new_name" => { "type" => "string" },
            "active" => { "type" => "boolean" }
          },
          "required" => [ "service", "name" ]
        }
      }
    ]
  end

  def call_tool(params)
    name = params["name"]
    args = params["arguments"] || {}

    return tool_error("Unknown tool: #{name}") unless tools.any? { |tool| tool["name"] == name }

    text = case name
    when "list_services" then list_services
    when "create_ticket" then create_ticket(args)
    when "list_my_tickets" then list_my_tickets(args)
    when "get_ticket" then get_ticket(args)
    when "my_queue" then my_queue(args)
    when "update_ticket_status" then update_ticket_status(args)
    when "create_service" then create_service(args)
    when "update_service" then update_service(args)
    when "create_topic" then create_topic(args)
    when "update_topic" then update_topic(args)
    end

    text.is_a?(Array) ? tool_error(text.first) : tool_result(text)
  end

  # --- tools -------------------------------------------------------------

  # Admins also see retired entries, since they're the ones who manage them.
  def list_services
    services = (user.admin? ? Service.all : Service.active).includes(:topics).order(:name)
    return "No services are configured yet." if services.empty?

    services.map do |service|
      topics = service.topics.select { |topic| topic.active? || user.admin? }
                      .map { |topic| topic.active? ? topic.name : "#{topic.name} (retired)" }

      label = service.active? ? service.name : "#{service.name} (retired)"
      "#{label}: #{topics.any? ? topics.join(', ') : '(no topics yet)'}"
    end.join("\n")
  end

  def create_ticket(args)
    service = Service.active.find_by("LOWER(name) = ?", args["service"].to_s.downcase)
    return [ "No service called #{args['service'].inspect}. Available:\n#{list_services}" ] if service.nil?

    topic = service.topics.active.find_by("LOWER(name) = ?", args["topic"].to_s.downcase)
    return [ "#{service.name} has no topic called #{args['topic'].inspect}. Available:\n#{list_services}" ] if topic.nil?

    ticket = user.tickets.new(
      title: args["title"],
      message: args["message"],
      service: service,
      topic: topic,
      priority: args["priority"].presence || "medium",
      url: args["url"].presence
    )

    return [ "Could not file it: #{ticket.errors.full_messages.to_sentence}" ] unless ticket.save

    "Filed ticket ##{ticket.id}.\n\n#{describe(ticket)}"
  end

  def list_my_tickets(args)
    scope = user.tickets.includes(:service, :topic).order(created_at: :desc)
    status = args["status"].presence
    scope = scope.where(status: status) if status && status != "all"

    return "You have no #{status == 'all' ? '' : "#{status} "}tickets." if scope.empty?

    scope.map { |ticket| summarize(ticket) }.join("\n")
  end

  def get_ticket(args)
    ticket = Ticket.find(args["id"])
    return [ "You don't have access to ticket ##{ticket.id}." ] unless user.admin? || ticket.user_id == user.id

    describe(ticket, full: true)
  end

  def my_queue(args)
    limit = [ args["limit"].to_i, 1 ].max
    limit = 25 if args["limit"].blank?

    tickets = Ticket.needs_attention.ordered_for_admin.includes(:user, :service, :topic).limit(limit)
    return "Nothing outstanding. 🎉" if tickets.empty?

    "#{tickets.size} waiting on you:\n" + tickets.map { |ticket| summarize(ticket, requester: true) }.join("\n")
  end

  def update_ticket_status(args)
    ticket = Ticket.find(args["id"])

    unless ticket.update(status: args["status"], status_note: args["note"].presence)
      return [ "Could not update it: #{ticket.errors.full_messages.to_sentence}" ]
    end

    notified = ticket.user.slack_id.present? ? " #{ticket.user.name.presence || 'They'} will get an email and a Slack DM." : " They'll get an email."
    "Ticket ##{ticket.id} is now #{ticket.status.humanize.downcase}.#{notified}"
  end

  def create_service(args)
    service = Service.new(name: args["name"].to_s.strip)
    return [ "Could not create it: #{service.errors.full_messages.to_sentence}" ] unless service.save

    topics = Array(args["topics"]).map(&:to_s).map(&:strip).reject(&:empty?)
    created = topics.filter_map { |name| service.topics.create(name: name).persisted? ? name : nil }

    "Created service #{service.name}." +
      (created.any? ? " Topics: #{created.join(', ')}." : " It has no topics yet — add some before anyone can file under it.")
  end

  def update_service(args)
    service = find_service(args["name"])
    return [ "No service called #{args['name'].inspect}. Available:\n#{list_services}" ] if service.nil?

    service.name = args["new_name"].to_s.strip if args["new_name"].present?
    service.active = args["active"] unless args["active"].nil?

    return [ "Could not update it: #{service.errors.full_messages.to_sentence}" ] unless service.save

    "#{service.name} is now #{service.active? ? 'active' : 'retired (hidden from the new-ticket form)'}."
  end

  def create_topic(args)
    service = find_service(args["service"])
    return [ "No service called #{args['service'].inspect}. Available:\n#{list_services}" ] if service.nil?

    topic = service.topics.new(name: args["name"].to_s.strip)
    return [ "Could not create it: #{topic.errors.full_messages.to_sentence}" ] unless topic.save

    "Added #{topic.name} under #{service.name}."
  end

  def update_topic(args)
    service = find_service(args["service"])
    return [ "No service called #{args['service'].inspect}. Available:\n#{list_services}" ] if service.nil?

    topic = service.topics.find_by("LOWER(name) = ?", args["name"].to_s.downcase.strip)
    return [ "#{service.name} has no topic called #{args['name'].inspect}." ] if topic.nil?

    topic.name = args["new_name"].to_s.strip if args["new_name"].present?
    topic.active = args["active"] unless args["active"].nil?

    return [ "Could not update it: #{topic.errors.full_messages.to_sentence}" ] unless topic.save

    "#{service.name} > #{topic.name} is now #{topic.active? ? 'active' : 'retired'}."
  end

  def find_service(name)
    Service.find_by("LOWER(name) = ?", name.to_s.downcase.strip)
  end

  # --- formatting --------------------------------------------------------

  def summarize(ticket, requester: false)
    parts = [
      "##{ticket.id}",
      ticket.title,
      (ticket.user.name.presence || ticket.user.email if requester),
      "#{ticket.service.name} > #{ticket.topic.name}",
      "#{ticket.priority} priority",
      ticket.status.humanize.downcase,
      "#{time_ago(ticket.created_at)} old"
    ].compact

    "- #{parts.join(' · ')}"
  end

  def describe(ticket, full: false)
    lines = [
      "##{ticket.id}: #{ticket.title}",
      "Status: #{ticket.status.humanize.downcase} · Priority: #{ticket.priority} · #{ticket.service.name} > #{ticket.topic.name}",
      "Filed by #{ticket.user.name.presence || ticket.user.email} #{time_ago(ticket.created_at)} ago",
      ("Link: #{ticket.url}" if ticket.url.present?),
      "Web: #{SlackNotifier.ticket_url(ticket)}"
    ].compact

    if full
      lines << "\n#{ticket.message}"
      lines << "\nLatest update: #{ticket.status_note}" if ticket.status_note.present?
    end

    lines.join("\n")
  end

  def time_ago(time)
    ActionController::Base.helpers.time_ago_in_words(time)
  end

  # --- JSON-RPC envelopes ------------------------------------------------

  def tool_result(text)
    { "content" => [ { "type" => "text", "text" => text.to_s } ] }
  end

  def tool_error(text)
    tool_result(text).merge("isError" => true)
  end

  def success(id, result)
    { "jsonrpc" => "2.0", "id" => id, "result" => result }
  end

  def error(id, code, message)
    { "jsonrpc" => "2.0", "id" => id, "error" => { "code" => code, "message" => message } }
  end
end

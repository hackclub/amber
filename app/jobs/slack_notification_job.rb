class SlackNotificationJob < ApplicationJob
  queue_as :default

  def perform(ticket_id, event)
    ticket = Ticket.find_by(id: ticket_id)
    return if ticket.nil?

    case event
    when "created" then SlackNotifier.ticket_created(ticket)
    when "status_changed" then SlackNotifier.ticket_status_changed(ticket)
    end
  end
end

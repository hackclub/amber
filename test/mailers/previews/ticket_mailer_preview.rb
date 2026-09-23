# Preview all emails at http://localhost:3000/rails/mailers/ticket_mailer
class TicketMailerPreview < ActionMailer::Preview
  # Preview this email at http://localhost:3000/rails/mailers/ticket_mailer/created
  def created
    TicketMailer.created(Ticket.first || Ticket.new(
      title: "Example ticket", message: "Example message",
      user: User.first, service: Service.first, topic: Topic.first
    ))
  end

  # Preview this email at http://localhost:3000/rails/mailers/ticket_mailer/status_changed
  def status_changed
    TicketMailer.status_changed(Ticket.first || Ticket.new(
      title: "Example ticket", message: "Example message",
      user: User.first, service: Service.first, topic: Topic.first
    ))
  end
end

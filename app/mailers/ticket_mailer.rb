class TicketMailer < ApplicationMailer
  def created(ticket)
    @ticket = ticket

    mail to: User.admin_emails, subject: "New ticket: #{ticket.title}"
  end

  def status_changed(ticket)
    @ticket = ticket

    mail to: ticket.user.email, subject: "Your ticket \"#{ticket.title}\" is now #{ticket.status.humanize}"
  end
end

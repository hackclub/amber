class DashboardController < ApplicationController
  skip_before_action :require_login

  def index
    return unless current_user

    if admin?
      @tickets = Ticket.needs_attention.ordered_for_admin.includes(:user, :service, :topic)
    else
      @tickets = current_user.tickets.order(created_at: :desc).includes(:service, :topic)
    end
  end
end

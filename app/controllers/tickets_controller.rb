class TicketsController < ApplicationController
  before_action :set_ticket, only: [ :show, :update ]
  before_action :authorize_ticket!, only: [ :show, :update ]

  def new
    @ticket = Ticket.new
    @services = Service.active.includes(:topics).order(:name)
  end

  def create
    @ticket = current_user.tickets.new(ticket_params)

    if @ticket.save
      redirect_to @ticket, notice: "Ticket submitted."
    else
      @services = Service.active.includes(:topics).order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def update
    unless admin?
      return redirect_to @ticket, alert: "Only an admin can update a ticket's status."
    end

    if @ticket.update(status_params)
      redirect_to request.referer.presence || @ticket, notice: "Ticket updated."
    else
      redirect_to @ticket, alert: @ticket.errors.full_messages.to_sentence
    end
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:id])
  end

  def authorize_ticket!
    return if admin? || @ticket.user_id == current_user.id

    redirect_to root_path, alert: "You don't have access to that ticket."
  end

  def ticket_params
    params.expect(ticket: [ :title, :service_id, :topic_id, :url, :priority, :message ])
  end

  def status_params
    params.expect(ticket: [ :status ])
  end
end

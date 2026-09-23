class TicketNotesController < ApplicationController
  before_action :require_admin!
  before_action :set_ticket

  def create
    note = @ticket.notes.new(body: params.dig(:ticket_note, :body), author: current_user)

    if note.save
      redirect_to @ticket, notice: "Note added."
    else
      redirect_to @ticket, alert: note.errors.full_messages.to_sentence
    end
  end

  def destroy
    @ticket.notes.find(params[:id]).destroy
    redirect_to @ticket, notice: "Note deleted."
  end

  private

  def set_ticket
    @ticket = Ticket.find(params[:ticket_id])
  end
end

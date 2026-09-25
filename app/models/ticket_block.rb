# "blocked_ticket is waiting on blocker_ticket".
class TicketBlock < ApplicationRecord
  belongs_to :blocked_ticket, class_name: "Ticket"
  belongs_to :blocker_ticket, class_name: "Ticket"

  validates :blocker_ticket_id, uniqueness: { scope: :blocked_ticket_id, message: "is already blocking this ticket" }
  validate :not_itself
  validate :no_cycle

  private

  def not_itself
    errors.add(:blocker_ticket, "can't block itself") if blocked_ticket_id == blocker_ticket_id
  end

  # Without this you can build a chain that waits on itself — A waits on B
  # waits on C waits on A — and nothing in it can ever be started.
  def no_cycle
    return if blocked_ticket.nil? || blocker_ticket.nil? || blocked_ticket_id == blocker_ticket_id

    return unless blocker_ticket.blocked_by_transitively?(blocked_ticket)

    errors.add(:blocker_ticket, "would create a loop: #{blocker_ticket.reference} already waits on #{blocked_ticket.reference}")
  end
end

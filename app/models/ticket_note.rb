# Private working notes on a ticket. Unlike Ticket#status_note, these are
# never sent to the requester and are only visible to admins.
class TicketNote < ApplicationRecord
  belongs_to :ticket
  belongs_to :author, class_name: "User"

  validates :body, presence: true

  scope :oldest_first, -> { order(created_at: :asc) }
end

class ChangeTicketPriorityDefaultToLow < ActiveRecord::Migration[8.1]
  def change
    # Keeps the column default in step with Ticket's enum default. Existing
    # tickets keep whatever priority they were filed with.
    change_column_default :tickets, :priority, from: 1, to: 0
  end
end

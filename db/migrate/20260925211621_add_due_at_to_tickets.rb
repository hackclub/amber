class AddDueAtToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :due_at, :datetime
  end
end

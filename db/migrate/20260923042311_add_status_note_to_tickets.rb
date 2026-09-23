class AddStatusNoteToTickets < ActiveRecord::Migration[8.1]
  def change
    add_column :tickets, :status_note, :text
  end
end

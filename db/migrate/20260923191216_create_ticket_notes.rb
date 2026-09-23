class CreateTicketNotes < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_notes do |t|
      t.references :ticket, null: false, foreign_key: true
      t.references :author, null: false, foreign_key: { to_table: :users }
      t.text :body, null: false

      t.timestamps
    end
  end
end

class CreateTicketBlocks < ActiveRecord::Migration[8.1]
  def change
    create_table :ticket_blocks do |t|
      t.references :blocked_ticket, null: false, foreign_key: { to_table: :tickets }
      t.references :blocker_ticket, null: false, foreign_key: { to_table: :tickets }

      t.timestamps
    end

    add_index :ticket_blocks, [ :blocked_ticket_id, :blocker_ticket_id ], unique: true
  end
end

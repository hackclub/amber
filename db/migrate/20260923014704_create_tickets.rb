class CreateTickets < ActiveRecord::Migration[8.1]
  def change
    create_table :tickets do |t|
      t.references :user, null: false, foreign_key: true
      t.references :service, null: false, foreign_key: true
      t.references :topic, null: false, foreign_key: true
      t.string :title, null: false
      t.string :url
      t.integer :priority, null: false, default: 1
      t.integer :status, null: false, default: 0
      t.text :message, null: false

      t.timestamps
    end
    add_index :tickets, :status
    add_index :tickets, :priority
  end
end

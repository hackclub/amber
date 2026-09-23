class CreateTopics < ActiveRecord::Migration[8.1]
  def change
    create_table :topics do |t|
      t.references :service, null: false, foreign_key: true
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :topics, [ :service_id, :name ], unique: true
  end
end

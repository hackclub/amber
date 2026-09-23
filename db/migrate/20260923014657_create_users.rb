class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :sub, null: false
      t.string :email, null: false
      t.string :name
      t.string :slack_id
      t.boolean :admin, null: false, default: false
      t.boolean :priority_boost, null: false, default: false

      t.timestamps
    end
    add_index :users, :sub, unique: true
  end
end

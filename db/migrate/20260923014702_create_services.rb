class CreateServices < ActiveRecord::Migration[8.1]
  def change
    create_table :services do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true

      t.timestamps
    end
    add_index :services, :name, unique: true
  end
end

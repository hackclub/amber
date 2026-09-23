class CreateOauthClients < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_clients do |t|
      t.string :client_id
      t.string :client_secret_digest
      t.string :name
      t.string :redirect_uris, array: true, default: []

      t.timestamps
    end
    add_index :oauth_clients, :client_id, unique: true
  end
end

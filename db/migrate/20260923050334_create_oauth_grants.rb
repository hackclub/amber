class CreateOauthGrants < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_grants do |t|
      t.references :oauth_client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :code_digest
      t.string :redirect_uri
      t.string :code_challenge
      t.string :scope
      t.string :resource
      t.datetime :expires_at

      t.timestamps
    end
    add_index :oauth_grants, :code_digest, unique: true
  end
end

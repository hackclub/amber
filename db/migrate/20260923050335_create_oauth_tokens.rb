class CreateOauthTokens < ActiveRecord::Migration[8.1]
  def change
    create_table :oauth_tokens do |t|
      t.references :oauth_client, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.string :access_token_digest
      t.string :refresh_token_digest
      t.string :scope
      t.datetime :expires_at
      t.datetime :revoked_at

      t.timestamps
    end
    add_index :oauth_tokens, :access_token_digest, unique: true
    add_index :oauth_tokens, :refresh_token_digest, unique: true
  end
end

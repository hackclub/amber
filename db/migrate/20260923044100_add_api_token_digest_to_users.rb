class AddApiTokenDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :api_token_digest, :string
    add_index :users, :api_token_digest, unique: true
  end
end

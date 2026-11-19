class MoveHrAccountsToDevise < ActiveRecord::Migration[8.1]
  def change
    # Devise can verify the existing bcrypt hashes under its standard column name.
    rename_column :hr_accounts, :password_digest, :encrypted_password
    add_column :hr_accounts, :reset_password_token, :string
    add_column :hr_accounts, :reset_password_sent_at, :datetime
    add_index :hr_accounts, :reset_password_token, unique: true
  end
end

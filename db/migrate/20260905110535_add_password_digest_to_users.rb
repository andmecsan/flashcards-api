class AddPasswordDigestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_digest, :string
    change_column_null :users, :uid, true
  end
end
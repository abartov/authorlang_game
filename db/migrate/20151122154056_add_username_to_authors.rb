class AddUsernameToAuthors < ActiveRecord::Migration
  def change
    add_column :authors, :username, :string
  end
end

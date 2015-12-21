class AddItalicsToAuthor < ActiveRecord::Migration
  def change
    add_column :authors, :italics, :text
  end
end

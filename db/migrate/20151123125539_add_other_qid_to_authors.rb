class AddOtherQidToAuthors < ActiveRecord::Migration
  def change
    add_column :authors, :other_qid, :integer
  end
end

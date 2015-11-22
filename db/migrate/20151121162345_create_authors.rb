class CreateAuthors < ActiveRecord::Migration
  def change
    create_table :authors do |t|
      t.integer :qid
      t.string :name
      t.integer :status
      t.integer :guess
      t.integer :heuristic
      t.integer :decision

      t.timestamps null: false
    end
    add_index :authors, :qid, unique: true
  end
end

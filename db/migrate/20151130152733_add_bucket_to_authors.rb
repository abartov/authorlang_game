class AddBucketToAuthors < ActiveRecord::Migration
  def change
    add_column :authors, :bucket, :integer
    add_index :authors, :bucket
    puts "Assigning random buckets to all existing records..."
    i = 0
    Author.all.each {|a| 
      a.bucket = rand(200)
      a.save!
      i += 1
      puts "#{i} done." if i % 2000 == 0
    }
  end
end

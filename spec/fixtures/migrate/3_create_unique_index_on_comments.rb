class CreateUniqueIndexOnComments < ActiveRecord::Migration[5.1]
  def change
    add_index :comments, :some_id_field, unique: true
  end
end

class RenameIndexOnComments < ActiveRecord::Migration[5.1]
  def change
    rename_index :comments, 'index_comments_on_some_id_field', 'new_index_comments_on_some_id_field'
  end
end

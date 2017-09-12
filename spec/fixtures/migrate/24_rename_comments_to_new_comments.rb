class RenameCommentsToNewComments < ActiveRecord::Migration[5.0]
  def change
    rename_table :comments, :new_comments
  end
end

class RenameSomeIdFieldToNewIdField < ActiveRecord::Migration[5.1]
  def change
    rename_column :comments, :some_id_field, :new_id_field
  end
end

class ChangeColumnNullFalse < ActiveRecord::Migration[5.0]
  def change
    change_column_null(:comments, :some_id_field, false)
  end
end

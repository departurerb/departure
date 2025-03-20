class ChangeColumnNullTrue < ActiveRecord::Migration[5.1]
  def change
    change_column_null(:comments, :some_id_field, true)
  end
end

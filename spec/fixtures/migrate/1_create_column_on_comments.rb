class CreateColumnOnComments < ActiveRecord::Migration[5.1]
  def change
    add_column(
      :comments,
      :some_id_field,
      :integer,
      { limit: 8, default: nil }
    )
  end
end

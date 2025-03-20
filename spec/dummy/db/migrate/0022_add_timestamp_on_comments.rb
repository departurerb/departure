class AddTimestampOnComments < ActiveRecord::Migration[5.1]
  def change
    add_timestamps :comments, null: true, default: nil
  end
end

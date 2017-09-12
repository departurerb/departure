class AddTimestampOnComments < ActiveRecord::Migration[5.0]
  def change
    add_timestamps :comments
  end
end

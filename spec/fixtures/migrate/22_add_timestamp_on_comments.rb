class AddTimestampOnComments < ActiveRecord::Migration[5.1]
  def change
    add_timestamps :comments
  end
end

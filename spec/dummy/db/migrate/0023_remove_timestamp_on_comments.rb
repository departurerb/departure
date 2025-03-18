class RemoveTimestampOnComments < ActiveRecord::Migration[5.1]
  def change
    remove_timestamps :comments
  end
end

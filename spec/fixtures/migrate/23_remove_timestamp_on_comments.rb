class RemoveTimestampOnComments < ActiveRecord::Migration[5.0]
  def change
    remove_timestamps :comments
  end
end

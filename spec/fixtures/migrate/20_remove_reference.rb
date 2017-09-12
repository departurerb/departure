class RemoveReference < ActiveRecord::Migration[5.0]
  def change
    remove_reference :comments, :user
  end
end

class RemoveReference < ActiveRecord::Migration[5.1]
  def change
    remove_reference :comments, :user
  end
end

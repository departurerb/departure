class AddReference < ActiveRecord::Migration[5.0]
  def change
    add_reference(:comments, :user)
  end
end

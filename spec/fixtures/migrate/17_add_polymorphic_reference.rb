class AddPolymorphicReference < ActiveRecord::Migration[5.0]
  def change
    add_reference(:comments, :user, polymorphic: true)
  end
end

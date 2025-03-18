class RemovePolymorphicReference < ActiveRecord::Migration[5.1]
  def change
    remove_reference :comments, :user, polymorphic: true
  end
end

class AddPolymorphicReferenceWithIndex < ActiveRecord::Migration[5.1]
  def change
    add_reference(:comments, :user, polymorphic: true, index: true)
  end
end

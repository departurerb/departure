class DataMigrationWithUpsertAll < ActiveRecord::Migration[5.1]
  def up
    add_column :comments, :author, :string

    return unless defined?(Comment.upsert_all)

    Comment.reset_column_information
    Comment.upsert_all([
      { author: "John", read: true },
      { author: "Smith", read: false }
    ])
  end

  def down; end
end

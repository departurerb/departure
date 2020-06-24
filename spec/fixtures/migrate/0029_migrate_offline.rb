class MigrateOffline < ActiveRecord::Migration[5.1]
  migrate_offline

  def change
    change_table :comments do |t|
      t.column :offline_migration_change, :integer
    end
  end
end

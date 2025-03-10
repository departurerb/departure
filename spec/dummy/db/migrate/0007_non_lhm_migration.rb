class NonLhmMigration < ActiveRecord::Migration[5.1]
  def up
    Lhm.change_table :products, { stride: 5000, throttle: 150 } do |p|
      p.add_column :price, 'VARCHAR(255)'
    end
  end

  def down
    Lhm.change_table :products, { stride: 5000, throttle: 150 } do |p|
      p.remove_column :price
    end
  end
end

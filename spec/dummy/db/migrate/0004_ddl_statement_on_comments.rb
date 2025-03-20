class DdlStatementOnComments < ActiveRecord::Migration[5.1]
  def up
    Lhm.change_table :comments, { stride: 5000, throttle: 150 } do |c|
      c.ddl("alter table #{c.name} my up ddl statement")
      c.ddl("alter table `#{c.name}` my up ddl statement")
    end
  end

  def down
    Lhm.change_table :comments, { stride: 5000, throttle: 150 } do |c|
      c.ddl("alter table #{c.name} my down ddl statement")
      c.ddl("alter table `#{c.name}` my down ddl statement")
    end
  end
end

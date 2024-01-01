class NoStatements < ActiveRecord::Migration[5.1]
  def up
    Lhm.change_table :comments, { stride: 5000, throttle: 150 } do |c| # rubocop:disable Lint/EmptyBlock
    end
  end

  def down
    Lhm.change_table :comments, { stride: 5000, throttle: 150 } do |c| # rubocop:disable Lint/EmptyBlock
    end
  end
end

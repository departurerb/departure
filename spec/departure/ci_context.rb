require 'spec_helper'

describe 'CI Context' do
  it 'uses the proper runner in integration specs', integration: true, activerecord_compatibility: RAILS_8_1 do
    establish_default_database_connection

    case ENV['DB_ADAPTER']
    when 'trilogy'
      expect(ActiveRecord::Base.connection.adapter_name).to eql('Trilogy')
    when 'mysql2'
      expect(ActiveRecord::Base.connection.adapter_name).to eql('Mysql2')
    else
      raise StandardError, 'Your test is not specifying a DB_ADAPTER of mysql2 or trilogy'
    end
  end
end

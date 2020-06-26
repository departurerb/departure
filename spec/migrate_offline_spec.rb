require 'spec_helper'

describe Departure, integration: true do
  let(:db_config) { Configuration.new }
  let(:migration_paths) { [MIGRATION_FIXTURES] }
  let(:direction) { :up }
  let(:connection_config) do
    {
      'default_env' => {
        'adapter' => 'mysql2',
        'host' => db_config['hostname'],
        'username' => db_config['username'],
        'password' => db_config['password'],
        'database' => db_config['database'],
      }
    }
  end

  Departure.load

  context 'when migrate_offline is called' do
    before do
      ActiveRecord::Base.configurations = connection_config
    end


    it 'runs with the mysql2 adapter' do
      ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, 29)
      expect(ActiveRecord::Base.connection_pool.spec.config[:adapter])
          .to eq('mysql2')
    end

    context 'when there are multiple offline migrations' do
      it 'runs all offline migrations with the mysql2 adapter' do
        [29, 30].each do |version|
          ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, version)
          expect(ActiveRecord::Base.connection_pool.spec.config[:adapter])
              .to eq('mysql2')
        end
      end
    end

    context 'when there are offline and online migrations' do
      it 'runs with the correct adapter' do
        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, 29)
        expect(ActiveRecord::Base.connection_pool.spec.config[:adapter])
            .to eq('mysql2')

        ActiveRecord::MigrationContext.new(migration_paths, ActiveRecord::SchemaMigration).run(direction, 28)
        expect(ActiveRecord::Base.connection_pool.spec.config[:adapter])
            .to eq('percona')
      end
    end
  end
end
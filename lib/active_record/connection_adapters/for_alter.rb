require 'active_record/connection_adapters/mysql/schema_statements'

module ForAlterStatements
  class << self
    def included(_)
      STDERR.puts 'Including for_alter statements'
    end
  end

  def bulk_change_table(table_name, operations) #:nodoc:
    sqls = operations.flat_map do |command, args|
      table = args.shift
      arguments = args

      method = :"#{command}_for_alter"

      raise "Unknown method called : #{method}(#{arguments.inspect})" unless respond_to?(method, true)
      public_send(method, table, *arguments)
    end.join(', ')

    execute("ALTER TABLE #{quote_table_name(table_name)} #{sqls}")
  end

  def change_column_for_alter(table_name, column_name, type, options = {})
    column = column_for(table_name, column_name)
    type ||= column.sql_type

    options = {
      default: column.default,
      null: column.null,
      comment: column.comment
    }.merge(options)

    td = create_table_definition(table_name)
    cd = td.new_column_definition(column.name, type, **options)
    schema_creation.accept(ActiveRecord::ConnectionAdapters::ChangeColumnDefinition.new(cd, column.name))
  end

  def rename_column_for_alter(table_name, column_name, new_column_name)
    column  = column_for(table_name, column_name)
    options = {
      default: column.default,
      null: column.null,
      auto_increment: column.auto_increment?
    }

    columns_sql = "SHOW COLUMNS FROM #{quote_table_name(table_name)} LIKE #{quote(column_name)}"
    current_type = exec_query(columns_sql, 'SCHEMA').first['Type']
    td = create_table_definition(table_name)
    cd = td.new_column_definition(new_column_name, current_type, **options)
    schema_creation.accept(ActiveRecord::ConnectionAdapters::ChangeColumnDefinition.new(cd, column.name))
  end

  def add_index_for_alter(table_name, column_name, options = {})
    index_definition, = add_index_options(table_name, column_name, **options)

    "ADD #{schema_creation.accept(index_definition)}"
  end

  def remove_index_for_alter(table_name, column_name = nil, **options)
    index_name = index_name_for_remove(table_name, column_name, options)

    "DROP INDEX #{quote_column_name(index_name)}"
  end

  def add_timestamps_for_alter(table_name, options = {})
    [
      add_column_for_alter(table_name, :created_at, :datetime, options),
      add_column_for_alter(table_name, :updated_at, :datetime, options)
    ]
  end

  def remove_timestamps_for_alter(table_name, _options = {})
    [remove_column_for_alter(table_name, :updated_at), remove_column_for_alter(table_name, :created_at)]
  end

  def add_column_for_alter(table_name, column_name, type, options = {})
    td = create_table_definition(table_name)
    cd = td.new_column_definition(column_name, type, **options)
    schema_creation.accept(ActiveRecord::ConnectionAdapters::AddColumnDefinition.new(cd))
  end

  def remove_column_for_alter(_table_name, column_name, _type = nil, _options = {})
    "DROP COLUMN #{quote_column_name(column_name)}"
  end

  def remove_columns_for_alter(table_name, *column_names, **options)
    column_names.map { |column_name| remove_column_for_alter(table_name, column_name) }
  end
end

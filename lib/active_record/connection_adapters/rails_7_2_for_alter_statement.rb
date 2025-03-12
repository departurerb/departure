require 'active_record/connection_adapters/mysql/schema_statements'
require 'active_record'

module Rails72ForAlterStatements
  extend ForAlterStatements
  include ForAlterStatements

  def remove_index_for_alter(table_name, column_name = nil, **options)
    index_name =
      if ActiveRecord::VERSION::STRING >= '6.1'
        index_name_for_remove(table_name, column_name, options)
      else
        options = [column_name, options] if column_name
        index_name_for_remove(table_name, options)
      end
    "DROP INDEX #{quote_column_name(index_name)}"
  end
end

module TableMethods
  def columns(table_name)
    ActiveRecord::Base.connection.columns(table_name)
  end

  def unique_indexes_from(table_name)
    indexes = indexes_from(table_name)
    indexes.select(&:unique).map(&:name)
  end

  def indexes_from(table_name)
    ActiveRecord::Base.connection.indexes(table_name)
  end

  def tables
    tables = ActiveRecord::Base.connection.select_all("SHOW TABLES")
    tables.flat_map(&:values)
  end
end

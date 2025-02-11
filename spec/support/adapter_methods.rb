module AdapterMethods
  def build_mysql_adapter_result(rows:, fields:)
    case original_adapter.to_s
    when 'mysql2'
      instance_double(Mysql2::Result, to_a: rows, fields: fields)
    when 'trilogy'
      instance_double(Trilogy::Result, rows: rows, fields: fields)
    end
  end

  def build_mysql_adapter
    case original_adapter.to_s
    when 'mysql2'
      instance_double(mysql_adapter_class)
    when 'trilogy'
      instance_double(mysql_adapter_class, exec_query: instance_double(ActiveRecord::Result))
    end
  end

  def build_mysql_client
    case original_adapter.to_s
    when 'mysql2'
      double(:mysql_client)
    when 'trilogy'
      double(:mysql_client, last_insert_id: 1)
    end
  end

  def mysql_adapter_class
    @mysql_adapter_class ||= case original_adapter.to_s
                             when 'mysql2'
                               ActiveRecord::ConnectionAdapters::Mysql2Adapter
                             when 'trilogy'
                               ActiveRecord::ConnectionAdapters::TrilogyAdapter
                             end
  end

  def original_adapter
    @original_adapter ||= Configuration.new['original_adapter']
  end
end

# frozen_string_literal: true

namespace :audit do
  task db: :environment do
    result = ActiveRecord::Base.connection.execute('SHOW TABLES;')

    puts "Tables in the database: #{result.to_a}"

    result = ActiveRecord::Base.connection.execute('SHOW INDEXES FROM comments;')

    puts "Indexes in the comments table: #{result.to_a}"
  end
end

class DataMigrationWithFindEach < ActiveRecord::Migration[5.1]
  class Comment < ActiveRecord::Base; end

  def up
    unread_comments = Comment.where(read: false)

    unread_comments.find_each do |unread_comment|
      unread_comment.read = true
      unread_comment.save
    end
  end

  def down; end
end

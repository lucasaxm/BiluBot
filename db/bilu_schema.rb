# -*- coding: utf-8 -*-
require_relative "#{__dir__}/../logger/logging"
require 'active_record'
require 'pg'

module BiluSchema
  include Logging
  class << self
    def create_db

      ActiveRecord::Base.establish_connection ENV['DATABASE_URL']
      begin
        ActiveRecord::Base.connection.create_table :chats do |t|
          t.string :telegram_id
          t.string :telegram_type
          t.string :grouptitle
          t.string :username
          t.boolean :nsfw
        end

        ActiveRecord::Base.connection.create_table :subreddits do |t|
          t.string :reddit_id
          t.string :name
          t.boolean :nsfw
        end

        ActiveRecord::Base.connection.create_table :reddit_posts do |t|
          t.string :reddit_id
          t.integer :subreddit_id
          t.text :title
          t.integer :score
          t.boolean :nsfw
          t.string :url
        end

        ActiveRecord::Base.connection.create_table :chats_reddit_posts do |t|
          t.integer :chat_id
          t.integer :reddit_post_id
        end

        ActiveRecord::Base.connection.create_table :banned_subreddits do |t|
          t.integer :chat_id
          t.integer :subreddit_id
        end
      rescue ActiveRecord::StatementInvalid => e
        return if e.cause.class.equal? PG::DuplicateTable

        logger.error e.cause
        raise e
      end
    end

  end

end
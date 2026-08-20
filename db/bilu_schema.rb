# -*- coding: utf-8 -*-
require_relative "#{__dir__}/../logger/logging"
require 'active_record'
require 'sqlite3'

module BiluSchema
  include Logging
  class << self
    # Default local SQLite database, used when DATABASE_URL isn't set.
    def default_database_url
      "sqlite3:#{File.expand_path('bilubot.sqlite3', __dir__)}"
    end

    def create_db

      ActiveRecord::Base.establish_connection(ENV.fetch('DATABASE_URL', default_database_url))
      ActiveRecord::Base.connection.create_table :chats, if_not_exists: true do |t|
        t.string :telegram_id
        t.string :telegram_type
        t.string :grouptitle
        t.string :username
        t.boolean :nsfw
      end

      ActiveRecord::Base.connection.create_table :subreddits, if_not_exists: true do |t|
        t.string :reddit_id
        t.string :name
        t.boolean :nsfw
      end

      ActiveRecord::Base.connection.create_table :reddit_posts, if_not_exists: true do |t|
        t.string :reddit_id
        t.integer :subreddit_id
        t.text :title
        t.integer :score
        t.boolean :nsfw
        t.string :url
      end

      ActiveRecord::Base.connection.create_table :chats_reddit_posts, if_not_exists: true do |t|
        t.integer :chat_id
        t.integer :reddit_post_id
      end

      ActiveRecord::Base.connection.create_table :banned_subreddits, if_not_exists: true do |t|
        t.integer :chat_id
        t.integer :subreddit_id
      end
    end

  end

end
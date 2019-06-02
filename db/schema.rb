# -*- coding: utf-8 -*-
class Schema
  require 'rubygems'
  require 'active_record'
  require 'sqlite3'

  ActiveRecord::Base.establish_connection :adapter => "sqlite3",
                                          :database => "Bilu.sqlite3"

  ActiveRecord::Base.connection.create_table :chats do |t|
    t.string :telegram_id
    t.string :telegram_type
    t.string :grouptitle
    t.string :username
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
end
require 'active_record'

class Subreddit < ActiveRecord::Base
  has_many :reddit_posts
  has_many :banned_subreddits
  has_many :chats, through: :banned_subreddits
end
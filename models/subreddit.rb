require 'active_record'

class Subreddit < ActiveRecord::Base
  has_many :reddit_posts
end
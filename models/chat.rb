require 'active_record'

class Chat < ActiveRecord::Base
  has_and_belongs_to_many :reddit_posts
  has_many :banned_subreddits
  has_many :subreddits, through: :banned_subreddits
end
require 'active_record'

class RedditPost < ActiveRecord::Base
  has_and_belongs_to_many :chats
  belongs_to :subreddit
end
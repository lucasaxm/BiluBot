require 'active_record'

class BannedSubreddit < ActiveRecord::Base
  belongs_to :subreddit
  belongs_to :chat
end
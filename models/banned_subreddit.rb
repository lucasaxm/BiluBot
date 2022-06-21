require 'active_record'

class BannedSubreddit < ActiveRecord::Base
  belongs_to :subreddits
  belongs_to :chats
end
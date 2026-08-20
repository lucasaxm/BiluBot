require 'dotenv'
require_relative '../logger/logging'
require_relative '../config/reddit_config'

# Standalone check that Reddit credentials + API access work, without Telegram.
# Usage: bundle exec ruby script/reddit_smoke_test.rb [subreddit]
Dotenv.load(File.expand_path('../tokens.env', __dir__))

subreddit_name = ARGV[0] || 'ruby'

session = RedditConfig.new_reddit_session
abort('Could not create a Reddit session. Check BILU_REDDIT_* env vars.') if session.nil?

subreddit = session.subreddit(subreddit_name)
puts "r/#{subreddit.display_name} id=#{subreddit.id} nsfw=#{subreddit.over_18?}"

posts = subreddit.hot(limit: 5)
puts "fetched #{posts.size} hot posts:"
posts.each_with_index do |post, i|
  puts "  #{i + 1}. [#{post.score}] #{post.title}"
  puts "     url=#{post.url}"
  puts "     self=#{post.self?} nsfw=#{post.over_18?} comments=#{post.comment_count} sub=#{post.subreddit.display_name}"
end

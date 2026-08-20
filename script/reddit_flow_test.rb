require 'json'
require 'faraday'
require 'telegram/bot'

# End-to-end-ish check of the /r command flow with stubbed Telegram + Reddit.
# Usage: bundle exec ruby script/reddit_flow_test.rb
ENV['DATABASE_URL'] = 'sqlite3::memory:'

require_relative '../db/bilu_schema'
require_relative '../routes'
require_relative '../router'
require_relative '../services/reddit_service'

BiluSchema.create_db

failures = []
check = lambda do |label, actual, expected|
  ok = actual == expected
  failures << "#{label}: expected #{expected.inspect}, got #{actual.inspect}" unless ok
  puts "#{ok ? 'PASS' : 'FAIL'} #{label} = #{actual.inspect}"
end

# --- Stub Telegram bot -------------------------------------------------------
class FakeApi
  attr_reader :calls

  def initialize = @calls = []

  def send_chat_action(**) = @calls << :send_chat_action
  def send_message(**args)
    @calls << :send_message
    { 'result' => { 'message_id' => 1 } }
  end
end

class FakeBilu
  attr_reader :bot, :texts

  Bot = Struct.new(:api)

  def initialize
    @api = FakeApi.new
    @bot = Bot.new(@api)
    @texts = []
  end

  def api = @api
  def reply_with_text(text, _message) = @texts << text
  def reply_with_markdown_text(text, _message) = @texts << text
end

# --- Stub Reddit -------------------------------------------------------------
stubs = Faraday::Adapter::Test::Stubs.new
stubs.post('https://www.reddit.com/api/v1/access_token') do
  [200, {}, { access_token: 'tok', expires_in: 3600 }.to_json]
end
stubs.get('/r/pics/about') { [200, {}, { data: { name: 't5_pics', over18: false } }.to_json] }
stubs.get('/r/pics/hot') do
  [200, {}, { data: { children: [
    { data: { id: 'p1', name: 't3_p1', title: 'First', score: 10, over_18: false, stickied: false,
              is_self: false, url: 'https://i.redd.it/1.jpg', permalink: '/r/pics/comments/p1/f/',
              num_comments: 3, subreddit: 'pics' } },
    { data: { id: 'p2', name: 't3_p2', title: 'Second', score: 5, over_18: false, stickied: false,
              is_self: false, url: 'https://i.redd.it/2.jpg', permalink: '/r/pics/comments/p2/s/',
              num_comments: 1, subreddit: 'pics' } }
  ] } }.to_json]
end

test_conn = Faraday.new { |f| f.adapter :test, stubs }
Reddit::Client.class_eval do
  define_method(:connection) { test_conn }
  define_method(:auth_connection) { test_conn }
end

# Capture what would be sent instead of shelling out to gallery-dl.
sent = []
RedditService.class_eval do
  define_method(:send_media) { |post| sent << post.name }
  define_method(:special_subreddit) { |_post| false }
end

def build_message(text)
  Telegram::Bot::Types::Message.new(
    message_id: 100, date: 0, text: text,
    chat: { id: 555, type: 'private', username: 'tester' },
    from: { id: 999, is_bot: false, first_name: 'Test', username: 'tester' }
  )
end

# --- Routing -----------------------------------------------------------------
msg = build_message('/r pics')
routes = Routes.message_map.select { |matcher, _| matcher.call(msg) }
check.call('routes matched for "/r pics"', routes.size, 1)
check.call('routed controller', routes.values.first[:controller], RedditController)
check.call('routed action', routes.values.first[:action], :get_media_from_subreddit)

# --- Chat persistence --------------------------------------------------------
chat = Router.save_chat(msg)
check.call('chat persisted', Chat.count, 1)
check.call('chat telegram_id', chat.telegram_id, '555')

# --- First fetch sends the first post ----------------------------------------
bilu = FakeBilu.new
RedditService.new(bilu, msg).get_media_from_subreddit(chat)
check.call('first call sent post', sent, ['t3_p1'])
check.call('subreddit saved', Subreddit.pluck(:name), ['pics'])
check.call('reddit post saved', RedditPost.pluck(:reddit_id), ['p1'])

# --- Second fetch skips the already-sent post --------------------------------
RedditService.new(bilu, build_message('/r pics')).get_media_from_subreddit(chat)
check.call('second call sent next post', sent, %w[t3_p1 t3_p2])

# --- Third fetch has nothing left --------------------------------------------
bilu3 = FakeBilu.new
RedditService.new(bilu3, build_message('/r pics')).get_media_from_subreddit(chat)
check.call('exhausted message', bilu3.texts, ['No available posts in this subreddit right now.'])

# --- Callback path (immutable Dry::Struct rebuild) ---------------------------
callback = Telegram::Bot::Types::CallbackQuery.new(
  id: 'cb1', chat_instance: 'ci', data: 'callback /r pics',
  from: { id: 999, is_bot: false, first_name: 'Test', username: 'tester' },
  message: build_message('whatever')
)
bilu4 = FakeBilu.new
RedditService.new(bilu4, callback).get_media_from_subreddit_callback(chat)
check.call('callback did not crash', bilu4.texts, ['No available posts in this subreddit right now.'])

# --- Banning -----------------------------------------------------------------
bilu5 = FakeBilu.new
RedditService.new(bilu5, build_message('/bsr pics')).ban_subreddit(chat)
check.call('ban persisted', BannedSubreddit.count, 1)
check.call('ban reply', bilu5.texts, ['subreddit pics banned'])

bilu6 = FakeBilu.new
RedditService.new(bilu6, build_message('/r pics')).get_media_from_subreddit(chat)
check.call('banned subreddit blocked', bilu6.texts, ['This subreddit is banned'])

bilu7 = FakeBilu.new
RedditService.new(bilu7, build_message('/usr pics')).unban_subreddit(chat)
check.call('unban persisted', BannedSubreddit.count, 0)

puts
if failures.empty?
  puts 'All reddit flow checks passed.'
else
  puts "FAILURES:\n#{failures.join("\n")}"
  exit 1
end

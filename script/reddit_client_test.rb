require 'faraday'
require 'json'
require_relative '../lib/reddit/session'

# Offline check of the Reddit client using stubbed HTTP responses.
# Usage: bundle exec ruby script/reddit_client_test.rb

stubs = Faraday::Adapter::Test::Stubs.new
stubs.post('https://www.reddit.com/api/v1/access_token') do
  [200, {}, { access_token: 'tok', expires_in: 3600 }.to_json]
end
stubs.get('/r/pics/about') do
  [200, {}, { data: { name: 't5_2qh0u', over18: false } }.to_json]
end
stubs.get('/r/pics/hot') do
  [200, {}, { data: { children: [
    { data: { id: 'abc', name: 't3_abc', title: 'A pic', score: 42, over_18: false, spoiler: false,
              stickied: false, is_self: false, url: 'https://i.redd.it/x.jpg',
              permalink: '/r/pics/comments/abc/a_pic/', num_comments: 7, subreddit: 'pics' } },
    { data: { id: 'def', name: 't3_def', title: 'Sticky', score: 1, stickied: true, is_self: true,
              selftext: 'hi', url: 'https://reddit.com/r/pics/def',
              permalink: '/r/pics/comments/def/s/', num_comments: 0, subreddit: 'pics' } }
  ] } }.to_json]
end
stubs.get('/r/nope/about') { [404, {}, 'not found'] }
stubs.get('/r/secret/about') { [403, {}, 'forbidden'] }
stubs.get('/api/info') do
  [200, {}, { data: { children: [
    { data: { id: 'zzz', name: 't3_zzz', title: 'From id', over_18: true, subreddit: 'pics',
              permalink: '/r/pics/comments/zzz/x/', url: 'https://i.redd.it/z.jpg' } }
  ] } }.to_json]
end

test_conn = Faraday.new { |f| f.adapter :test, stubs }
Reddit::Client.class_eval do
  define_method(:connection) { test_conn }
  define_method(:auth_connection) { test_conn }
end

failures = []
check = lambda do |label, actual, expected|
  ok = actual == expected
  failures << "#{label}: expected #{expected.inspect}, got #{actual.inspect}" unless ok
  puts "#{ok ? 'PASS' : 'FAIL'} #{label} = #{actual.inspect}"
end

session = Reddit::Session.new(client_id: 'id', secret: 'sec', user_agent: 'ua')

subreddit = session.subreddit('pics')
check.call('subreddit.id', subreddit.id, 't5_2qh0u')
check.call('subreddit.over_18?', subreddit.over_18?, false)

posts = subreddit.hot
check.call('hot count', posts.size, 2)

post = posts.first
check.call('post.id', post.id, 'abc')
check.call('post.name', post.name, 't3_abc')
check.call('post.title', post.title, 'A pic')
check.call('post.score', post.score, 42)
check.call('post.over_18?', post.over_18?, false)
check.call('post.self?', post.self?, false)
check.call('post.comment_count', post.comment_count, 7)
check.call('post.subreddit.display_name', post.subreddit.display_name, 'pics')
check.call('post.to_h symbol keys', post.to_h[:title], 'A pic')

# This mirrors how RedditService filters listings.
check.call('non-stickied filter', posts.to_a.select { |h| !h.stickied? }.size, 1)

from_id = session.from_ids('t3_zzz').first
check.call('from_ids title', from_id.title, 'From id')
check.call('from_ids over_18?', from_id.over_18?, true)

begin
  session.subreddit('nope').id
  failures << '404 did not raise'
rescue Reddit::Errors::NotFound
  puts 'PASS 404 -> Reddit::Errors::NotFound'
end

begin
  session.subreddit('secret').id
  failures << '403 did not raise'
rescue Reddit::Errors::Forbidden
  puts 'PASS 403 -> Reddit::Errors::Forbidden'
end

puts
if failures.empty?
  puts 'All Reddit client checks passed.'
else
  puts "FAILURES:\n#{failures.join("\n")}"
  exit 1
end

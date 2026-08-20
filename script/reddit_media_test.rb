require 'dotenv'
require_relative '../logger/logging'
require_relative '../config/reddit_config'
require_relative '../lib/reddit/video_downloader'

# Exercises the new direct-download reddit media dispatch logic against real
# posts, without needing gallery-dl or a Telegram bot.
# Usage: bundle exec ruby script/reddit_media_test.rb
Dotenv.load(File.expand_path('../tokens.env', __dir__))

ids = %w[t3_1vrww2p t3_1vp1q3e t3_1vr9zl5 t3_1vrrvx5 t3_1vsvtww t3_1vt6laa]

session = RedditConfig.new_reddit_session
abort('Could not create a Reddit session.') if session.nil?

posts = session.from_ids(ids)
puts "fetched #{posts.size} posts"

posts.each do |post|
  kind = if post.self?
           'self'
         elsif post.gallery?
           "gallery (#{post.gallery_urls.size} images)"
         elsif !post.reddit_video.nil?
           "video (has_audio=#{post.reddit_video['has_audio']})"
         elsif post.reddit_hosted_media?
           'image'
         else
           "external (#{post.domain})"
         end
  puts "- #{post.id} [#{kind}] #{post.title}"
end

video_post = posts.find { |p| !p.reddit_video.nil? }
if video_post
  puts "\ndownloading+muxing video for #{video_post.id}..."
  Dir.mktmpdir('reddit_video_test') do |dir|
    path = Reddit::VideoDownloader.download(video_post.reddit_video, dir)
    if path.nil?
      puts 'VideoDownloader returned nil (no audio track or download/mux failed) - would fall back to fallback_url'
    else
      info = `ffprobe -v error -show_entries stream=codec_type -of default=noprint_wrappers=1 "#{path}" 2>&1`
      puts "muxed file: #{path} (#{File.size(path)} bytes)"
      puts info
    end
  end
end

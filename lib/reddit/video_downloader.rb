require 'down'
require 'nokogiri'
require 'terrapin'
require 'fileutils'

module Reddit
  ##
  # Downloads a Reddit-hosted (v.redd.it) video and muxes it with its separate
  # audio track via ffmpeg, since Telegram can't do that itself like it can for
  # a plain image/video URL.
  class VideoDownloader
    MAX_SIZE = 50 * 1024 * 1024 # Telegram bot API upload limit

    def self.download(reddit_video, destination_dir)
      new(reddit_video, destination_dir).download
    end

    def initialize(reddit_video, destination_dir)
      @reddit_video = reddit_video
      @destination_dir = destination_dir
    end

    # Returns a local path to a muxed video+audio file, or nil if there's no
    # separate audio track to mux (caller should just use fallback_url then)
    # or the download/mux failed.
    def download
      return nil unless @reddit_video['has_audio']

      audio_url = find_audio_url
      return nil if audio_url.nil?

      video_path = fetch(video_url, 'video.mp4')
      return nil if video_path.nil?

      audio_path = fetch(audio_url, 'audio.mp4')
      return nil if audio_path.nil?

      mux(video_path, audio_path)
    end

    private

    def video_url
      @reddit_video['fallback_url']
    end

    def base_url
      video_url.split('?').first.split('/')[0..-2].join('/')
    end

    def find_audio_url
      manifest = Down.download(@reddit_video['dash_url'], max_size: 2 * 1024 * 1024).read
      doc = Nokogiri::XML(manifest)
      doc.remove_namespaces!
      audio_files = doc.css('AdaptationSet[contentType="audio"] Representation BaseURL').map(&:text)
      return nil if audio_files.empty?

      "#{base_url}/#{audio_files.last}"
    rescue StandardError
      nil
    end

    def fetch(url, filename)
      FileUtils.mkdir_p(@destination_dir)
      temp = Down.download(url, max_size: MAX_SIZE)
      path = File.join(@destination_dir, filename)
      FileUtils.mv(temp.path, path)
      path
    rescue Down::Error
      nil
    end

    def mux(video_path, audio_path)
      output_path = File.join(@destination_dir, 'muxed.mp4')
      Terrapin::CommandLine.new(
        'ffmpeg',
        '-y -i :video -i :audio -c copy -map 0:v:0 -map 1:a:0 :output'
      ).run(video: video_path, audio: audio_path, output: output_path)
      output_path
    rescue Terrapin::ExitStatusError, Terrapin::CommandNotFoundError
      nil
    end
  end
end

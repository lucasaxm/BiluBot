require 'json'
module GalleryDLConfig
  class << self
    def save_config
      # Windows
      File.write(File.join(Dir.home, 'gallery-dl.conf'), @default.to_json)
      # Linux
      File.write(File.join(Dir.home, '.gallery-dl.conf'), @default.to_json)
      File.write(File.join("#{__dir__}", 'youtubedl.conf'), @youtubedl.to_json)
    end
  end

  @default = {
    extractor: {
      filename: '{filename|id}.{extension}',
      twitter: {
        cards: 'ytdl'
      },
      ytdl: {
        enabled: true,
        format: 'bestvideo[filesize<35M][ext=mp4]+bestaudio[filesize<15M][ext=m4a]/bestvideo[filesize_approx<35M][ext=mp4]+bestaudio[filesize_approx<15M][ext=m4a]/bestvideo[filesize<40M][ext=mp4]+bestaudio[filesize<10M][ext=m4a]/bestvideo[filesize_approx<40M][ext=mp4]+bestaudio[filesize_approx<10M][ext=m4a]/bestvideo[filesize<15M][ext=mp4]+bestaudio[filesize<35M][ext=m4a]/bestvideo[filesize_approx<15M][ext=mp4]+bestaudio[filesize_approx<35M][ext=m4a]/bestvideo[filesize<10M][ext=mp4]+bestaudio[filesize<40M][ext=m4a]/bestvideo[filesize_approx<10M][ext=mp4]+bestaudio[filesize_approx<40M][ext=m4a]/best[filesize<50M][ext=mp4]/best[filesize_approx<50M][ext=mp4]/bestvideo[height<=360][ext=mp4]+bestaudio[ext=m4a]/bestvideo[filesize<35M]+bestaudio[filesize<15M][ext=m4a]/bestvideo[filesize_approx<35M]+bestaudio[filesize_approx<15M][ext=m4a]/bestvideo[filesize<40M]+bestaudio[filesize<10M][ext=m4a]/bestvideo[filesize_approx<40M]+bestaudio[filesize_approx<10M][ext=m4a]/bestvideo[filesize<15M]+bestaudio[filesize<35M][ext=m4a]/bestvideo[filesize_approx<15M]+bestaudio[filesize_approx<35M][ext=m4a]/bestvideo[filesize<10M]+bestaudio[filesize<40M][ext=m4a]/bestvideo[filesize_approx<10M]+bestaudio[filesize_approx<40M][ext=m4a]/best[filesize<50M]/best[filesize_approx<50M]/bestvideo[height<=360]+bestaudio[ext=m4a]/best',
        logging: true,
        "cmdline-args": "--cookies #{File.join(Dir.home, 'cookies.txt')} --write-thumbnail --convert-thumbnails jpg --http-chunk-size 8M --max-filesize 52428800 --merge-output-format mp4",
        module: 'yt_dlp',
        Facebook: {
          filename: '{id}.{extension}'
        },
        Steam: {
          filename: '{id}.{extension}'
        }
      }
    },
    downloader: {
      'filesize-max': '50M'
    }
  }

  @youtubedl = {
    extractor: {
      ytdl: {
        "cmdline-args": "--cookies #{File.join(Dir.home, 'cookies.txt')} --write-thumbnail --http-chunk-size 8M --max-filesize 52428800 --merge-output-format mp4",
        module: 'youtube_dl'
      }
    }
  }
end

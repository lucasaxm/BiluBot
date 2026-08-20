module Reddit
  ##
  # Wraps a Reddit "link" (t3) API payload with the small surface the bot needs.
  class Submission
    SubredditRef = Struct.new(:display_name)

    attr_reader :data

    def initialize(data)
      @data = data
    end

    def id
      data['id']
    end

    def name
      data['name'] || "t3_#{data['id']}"
    end

    def title
      data['title']
    end

    def author
      data['author']
    end

    def score
      data['score']
    end

    def url
      data['url_overridden_by_dest'] || data['url']
    end

    # An i.redd.it image that's actually an animated GIF, not a static photo.
    def gif?
      url.to_s.downcase.end_with?('.gif')
    end

    # Reddit's own mp4 transcode of the gif - a small muted video Telegram can
    # actually fetch, unlike the raw GIF which is often 10-60x the file size
    # and gets rejected by Telegram's URL fetcher.
    def gif_video_url
      mp4 = data.dig('preview', 'images', 0, 'variants', 'mp4', 'source', 'url')
      mp4 ? mp4.gsub('&amp;', '&') : url
    end

    def permalink
      data['permalink']
    end

    def comment_count
      data['num_comments']
    end

    def over_18?
      !!data['over_18']
    end

    def spoiler?
      !!data['spoiler']
    end

    def stickied?
      !!data['stickied']
    end

    def self?
      !!data['is_self']
    end

    def selftext
      data['selftext']
    end

    def is_reddit_media_domain
      !!data['is_reddit_media_domain']
    end

    def is_video
      !!data['is_video']
    end

    def media
      data['media']
    end

    def media_metadata
      data['media_metadata']
    end

    def poll_data
      data['poll_data']
    end

    def domain
      data['domain']
    end

    def gallery?
      !!data['is_gallery']
    end

    # Direct, full-resolution CDN URLs for a gallery post, in display order.
    def gallery_urls
      return [] unless gallery?

      items = data.dig('gallery_data', 'items') || []
      metadata = data['media_metadata'] || {}
      items.filter_map do |item|
        meta = metadata[item['media_id']]
        next if meta.nil? || meta['status'] != 'valid'

        source = meta['s'] || {}
        source['u'] || source['gif'] || source['mp4']
      end
    end

    # Reddit-hosted (v.redd.it) video info, or nil if this isn't a hosted video.
    def reddit_video
      return nil unless data['is_video']

      data.dig('secure_media', 'reddit_video') || data.dig('media', 'reddit_video')
    end

    # True when the media lives on Reddit's own CDN (as opposed to an external link).
    def reddit_hosted_media?
      gallery? || !reddit_video.nil? || %w[i.redd.it preview.redd.it].include?(domain)
    end

    def subreddit
      SubredditRef.new(data['subreddit'])
    end

    def to_h
      data.transform_keys(&:to_sym)
    end
  end
end

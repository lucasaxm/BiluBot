require_relative "#{__dir__}/../logger/logging"
require 'faraday'

class ScreenshotService
  include Logging

  def initialize(bilu, message)
    @bilu = bilu
    @message = message
    @image_service = ImageService.new(bilu, message)
    @gallerydl_service = GalleryDLService.new(bilu, message)
    @dir = "#{__dir__}/#{Thread.current.object_id}"
  end

  def take_screenshot(_chat)
    msg = @message
    urls = extract_urls msg
    if urls.empty? && !@message.reply_to_message.nil?
      msg = @message.reply_to_message
      urls = extract_urls msg
      if urls.empty?
        @bilu.bot.api.send_message({ chat_id: msg.chat.id,
                                     text: 'no URL found in this message',
                                     reply_to_message_id: msg.message_id,
                                     allow_sending_without_reply: true })
        nil
      end
    end

    @bilu.bot.api.send_chat_action(
      chat_id: msg.chat.id,
      action: 'upload_photo'
    )
    medias = urls.map do |url|
      logger.info("Taking screenshot of #{url} and attaching to media group.")
      options = {
        response_type: 'json',
        format: 'jpeg',
        wait_until: 'network_idle',
        no_ads: true,
        no_cookie_banners: true,
        width: 720,
        height: 1080,
        quality: 100
      }
      {
        type: 'photo',
        media: ScreenshotService.screenshot_url(url, options),
        caption: url
      }
    end
    unless medias.empty?
      medias.each_slice(10) do |medias_slice|
        logger.info("Sending #{medias_slice.size} photos as media group.")
        @bilu.bot.api.send_media_group(
          chat_id: msg.chat.id,
          reply_to_message_id: msg.message_id,
          allow_sending_without_reply: true,
          media: medias_slice
        )
      end
    end
  end

  def leia_isso(_chat)
    msg = @message
    urls = extract_urls msg
    if urls.empty? && !@message.reply_to_message.nil?
      msg = @message.reply_to_message
      urls = extract_urls msg
      if urls.empty?
        @bilu.bot.api.send_message({ chat_id: msg.chat.id,
                                     text: 'no URL found in this message',
                                     reply_to_message_id: msg.message_id,
                                     allow_sending_without_reply: true })
        nil
      end
    end

    @bilu.bot.api.send_chat_action(
      chat_id: msg.chat.id,
      action: 'upload_photo'
    )
    medias = urls.flat_map do |url|
      leiaissourl = "https://leiaisso.net/#{url}"
      logger.info("Taking screenshot of #{leiaissourl} and attaching to media group.")
      options = {
        response_type: 'json',
        format: 'jpeg',
        wait_until: 'network_idle',
        element: '.post .wrap',
        quality: 100,
        width: 650
      }
      screenshot_url = ScreenshotService.screenshot_url(leiaissourl, options)
      image_chunk_paths = @image_service.split_image_and_save(screenshot_url, 1080)
      image_chunk_paths.map do |file_path|
        upload = Faraday::UploadIO.new(file_path, 'image/jpeg')
        {
          type: 'photo',
          media: @gallerydl_service.upload_to_telegram('photo', upload),
          caption: leiaissourl
        }
      end
    end
    unless medias.empty?
      medias.each_slice(10) do |medias_slice|
        logger.info("Sending #{medias_slice.size} photos as media group.")
        @bilu.bot.api.send_media_group(
          chat_id: msg.chat.id,
          reply_to_message_id: msg.message_id,
          allow_sending_without_reply: true,
          media: medias_slice
        )
      end
    end
  ensure
    logger.warn "cleaning thread local dir #{`rm -rf #{@dir}`.inspect}"
  end


  def self.get_connection(token = nil)
    api_url = 'https://api.apiflash.com/v1'
    token = get_available_token if token.nil?
    Faraday.new(url: api_url, params: { access_key: token }) do |f|
      f.response :json
      f.request :json
      f.response :logger
      f.adapter Faraday.default_adapter
    end
  end

  def self.get_available_token
    tokens = ENV['BILU_APIFLASH_ACCESS_KEY'].split(',')
    tokens.detect do |t|
      next if t.nil?

      conn = get_connection t
      response = conn.get('urltoimage/quota')
      raise StandardError, "code: #{response.status}" if response.status != 200

      response.body['remaining'] > 0
    end
  end

  def self.screenshot_url(target_url, options = {})
    conn = get_connection

    response = conn.get('urltoimage') do |req|
      req.params['url'] = target_url
      req.params.merge!(options)
    end

    raise StandardError, "code: #{response.status}" if response.status != 200

    response.body['url']
  end

  private

  def extract_urls(msg)
    msg['entities'].select do |entity|
      entity['type'] == 'url' || entity['type'] == 'text_link'
    end.map do |url_entity|
      if url_entity['type'] == 'url'
        msg['text'].chars.map do |x|
          x.bytes.each_slice(2).to_a
        end.flatten(1)[url_entity['offset'], url_entity['offset'] + url_entity['length']].flatten.pack('C*')
      else # text_link
        url_entity['url']
      end
    end
  end

end

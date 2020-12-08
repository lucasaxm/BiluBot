module GalleryDL
  # Video model for using and downloading a single media.
  class Media < Runner
    class << self
      # Instantiate a new Video model and download the media
      #
      #   YoutubeDL.download 'https://www.youtube.com/watch?v=KLRDLIIl8bA' # => #<YoutubeDL::Video:0x00000000000000>
      #   YoutubeDL.get 'https://www.youtube.com/watch?v=ia1diPnNBgU', extract_audio: true, audio_quality: 0
      #
      # @param url [String] URL to use and download
      # @param options [Hash] Options to pass in
      # @return [GalleryDL::Media] new Video model
      def download(url, options = {})
        media = new(url, options)
        media.download
        media
      end

      alias_method :get, :download
    end

    # @return [GalleryDL::Options] Download Options for the last download
    attr_reader :download_options

    # Instantiate new model
    #
    # @param url [String] URL to initialize with
    # @param options [Hash] Options to populate the everything with
    def initialize(url, options = {})
      @url = url
      @options = GalleryDL::Options.new(options.merge(default_options))
      @options.banned_keys = banned_keys
    end

    # Download the media.
    def download
      raise ArgumentError.new('url cannot be nil') if @url.nil?
      raise ArgumentError.new('url cannot be empty') if @url.empty?

      set_information_from_json(GalleryDL::Runner.new(url, runner_options).run)
    end

    alias_method :get, :download

    # Returns the expected filename
    #
    # @return [String] Filename downloaded to
    def filename
      self._filename
    end

    # Metadata information for the media, gotten from --print-json
    #
    # @return [OpenStruct] information
    def information
      @information || grab_information_without_download
    end

    # Redirect methods for information getting
    #
    # @param method [Symbol] method name
    # @param args [Array] method arguments
    # @param block [Proc] explict block
    # @return [Object] The value from @information
    def method_missing(method, *args, &block)
      value = information[method]

      if value.nil?
        super
      else
        value
      end
    end

    private

    # Add in other default options here.
    def default_options
      {
          write_metadata: true
      }
    end

    def banned_keys
      [
          :get_url,
          :get_title,
          :get_id,
          :get_thumbnail,
          :get_description,
          :get_duration,
          :get_filename,
          :get_format
      ]
    end

    def runner_options
      GalleryDL::Options.new(@options.to_h.merge(default_options))
    end

    def set_information_from_json(files) # :nodoc:
      @information = files.split("\n").map { |file| get_metadata((file[0] == '#' ? file[1..-1] : file).strip) }
    end

    def grab_information_without_download # :nodoc:
      set_information_from_json(GalleryDL::Runner.new(url, runner_options.with({dump_json: true})).run)
    end

    def get_metadata(file)
      unless File.exists? file
        logger.error("Couldn't extract metadata #{file} doesn't exists")
        return
      end
      metadata_file = "#{file}.json"
      unless File.exists? metadata_file
        logger.error("Couldn't extract metadata #{file} doesn't exists")
        return
      end
      json_parse = JSON.parse(File.read(metadata_file), symbolize_names: true)
      json_parse[:local_path] = file
      json_parse
    end
  end
end

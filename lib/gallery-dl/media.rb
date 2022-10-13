module GalleryDL
  # Video model for using and downloading a single media.
  class Media < Runner
    class << self
      # Instantiate a new Media model and download the media
      #
      #   GalleryDL.download 'https://www.youtube.com/watch?v=KLRDLIIl8bA' # => #<GalleryDL::Media:0x00000000000000>
      #   GalleryDL.get 'https://www.youtube.com/watch?v=ia1diPnNBgU', extract_audio: true, audio_quality: 0
      #
      # @param url [String] URL to use and download
      # @param options [Hash] Options to pass in
      # @return [GalleryDL::Media] new Video model
      def download(url, timeout=30, options = {})
        media = new(url, timeout, options)
        media.download
        media
      end

      def fetch_metadata(url, timeout=30, options = {})
        media = new(url, timeout, options)
        media.fetch_metadata
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
    def initialize(url, timeout=30, options = {}, information = nil)
      @url = url
      @options = GalleryDL::Options.new(options.merge(default_options))
      @options.banned_keys = banned_keys
      @timeout = timeout
      @information = information unless information.nil?
    end

    # Download the media.
    def download
      raise ArgumentError.new('url cannot be nil') if @url.nil?
      raise ArgumentError.new('url cannot be empty') if @url.empty?

      set_information_from_json(GalleryDL::Runner.new(url, @timeout, runner_options).run)
    end

    def fetch_metadata
      # gallery-dl --no-download 'https://www.instagram.com/lucasaxm/'
      raise ArgumentError.new('url cannot be nil') if @url.nil?
      raise ArgumentError.new('url cannot be empty') if @url.empty?
      
      set_information_from_json(GalleryDL::Runner.new(url, @timeout, runner_options.with({no_download: true})).run, false)
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
      @information
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

    def set_information_from_json(files, downloaded=true) # :nodoc:
      @information = files.split("\n").map { |file| get_metadata((file[0] == '#' ? file[1..-1] : file).strip, downloaded) }
    end

    def get_metadata(file, downloaded)
      if (downloaded && !(File.exists?(file)))
        logger.error("Couldn't extract metadata #{file} doesn't exists")
        return
      end
      metadata_file = "#{file}.json"
      unless File.exists? metadata_file
        logger.error("Couldn't extract metadata #{metadata_file} doesn't exists")
        return
      end
      json_parse = JSON.parse(File.read(metadata_file), symbolize_names: true)
      if downloaded
        json_parse[:local_path] = file
      end
      json_parse
    end
  end
end

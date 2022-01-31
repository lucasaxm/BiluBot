module GalleryDL
  # Utility class for running and managing gallery-dl
  class Runner
    include GalleryDL::Support

    # @return [String] URL to download
    attr_accessor :url

    # @return [GalleryDL::Options] Options access.
    attr_accessor :options

    # @return [String] Executable path
    attr_reader :executable_path

    # @return [String] Executable name to use
    attr_accessor :executable

    # Command Line runner initializer
    #
    # @param url [String] URL to pass to gallery-dl executable
    # @param options [Hash, Options] options to pass to the executable. Automatically converted to Options if it isn't already
    def initialize(url, options = {})
      @url = url
      @options = GalleryDL::Options.new(options)
      @executable = 'gallery-dl'
    end

    # Returns usable executable path for gallery-dl
    #
    # @return [String] usable executable path for gallery-dl
    def executable_path
      @executable_path ||= usable_executable_path_for(@executable)
    end

    # Returns terrapin's runner engine
    #
    # @return [CommandLineRunner] backend runner class
    def backend_runner
      Terrapin::CommandLine.runner
    end

    # Sets terrapin's runner engine
    #
    # @param terrapin_runner [CommandLineRunner] backend runner class
    # @return [Object] whatever terrapin::CommandLine.runner= returns.
    def backend_runner=(terrapin_runner)
      Terrapin::CommandLine.runner = terrapin_runner
    end

    # Returns the command string without running anything
    #
    # @return [String] command line string
    def to_command
      terrapin_line(options_to_commands).command(@options.store)
    end

    alias_method :command, :to_command

    # Runs the command
    #
    # @return [String] the output of gallery-dl
    def run
      Timeout::timeout(300, nil, "Terrapin run timeout. options=[#{options_to_commands}]") do
        terrapin_line(options_to_commands).run(@options.store)
      end
    end

    alias_method :download, :run

    # Options configuration.
    # Just aliases to options.configure
    #
    # @yield [config] options
    # @param a [Array] arguments to pass to options#configure
    # @param b [Proc] block to pass to options#configure
    def configure(*a, &b)
      options.configure(*a, &b)
    end

    private

    # Parses options and converts them to terrapin's syntax
    #
    # @return [String] commands ready to do terrapin
    def options_to_commands
      commands = []
      @options.sanitize_keys.each_paramized_key do |key, paramized_key|
        if @options[key].to_s == 'true'
          commands.push "--#{paramized_key}"
        elsif @options[key].to_s == 'false'
          commands.push "--no-#{paramized_key}"
        else
          commands.push "--#{paramized_key} :#{key}"
        end
      end
      commands.push quoted(url)
      commands.join(' ')
    end
  end
end

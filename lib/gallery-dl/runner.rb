require_relative "#{__dir__}/errors"

module GalleryDL
  # Utility class for running and managing gallery-dl
  class Runner
    include Logging
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
    def initialize(url, timeout=30, options = {})
      @url = url
      @timeout = timeout
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
      # Timeout::timeout(300, nil, "Terrapin run timeout. options=[#{options_to_commands}]") do
      #   terrapin_line(options_to_commands).run(@options.store)
      # end
      command = to_command
      logger.debug "terrapin command is #{command}"
      processes_dir = 'processes'
      lockfile = "#{__dir__}/#{processes_dir}/#{Thread.current.object_id}.lock"
      system "mkdir -p #{__dir__}/#{processes_dir}"
      system "touch #{lockfile}"
      processes_dir = Dir["#{__dir__}/**/#{processes_dir}"].first
      child_pid = fork do
        Process.setsid

        # puts "[PID:#{Process.pid}][TID:#{Thread.current.object_id}] command: #{command}."
        system "#{command} > #{processes_dir}/#{Process.pid}.out 2> #{processes_dir}/#{Process.pid}.error"
        logger.info "gallery-dl command completed, removing lockfile. #{`rm -fv #{lockfile}`.inspect}"
      end
      # puts "[PID:#{Process.pid}][TID:#{Thread.current.object_id}] waiting for process #{child_pid} to finish."
    
      begin
        Timeout::timeout(@timeout, nil, "Command #{command} run timeout. Killing process #{child_pid}.") do
          # puts `ps --pid #{child_pid} -o state | tail -1` bnmʋ
          while File.exists?(lockfile)
            # puts `ps --pid #{child_pid} -o state | tail -1`
          end
        end
        stderr_lines = File.readable?("#{processes_dir}/#{child_pid}.error") ? File.readlines("#{processes_dir}/#{child_pid}.error") : []
        output = File.read "#{processes_dir}/#{child_pid}.out"
        error_lines = stderr_lines.filter{|line| line.start_with? '['}.filter{|line| (!line.include? '[warning]') && (!line.include? '[info]') && (!line.include? '[debug]')}
        if (!error_lines.empty?) && (!error_lines.filter{|line| !line.downcase.include? 'conversion failed'}.empty?)
          raise GalleryDL::GalleryDlError, "stdout:\n#{output}stderr:\n#{stderr_lines.join}"
        end
        output
        # puts "[PID:#{Process.pid}][TID:#{Thread.current.object_id}] output=[#{output.inspect}]"
        # puts "[PID:#{Process.pid}][TID:#{Thread.current.object_id}] error=[#{error.inspect}]"
      rescue Timeout::Error => e
        pgid = Process.getpgid(child_pid)
        # puts "[PID:#{Process.pid}][TID:#{Thread.current.object_id}] Sending HUP to group #{pgid}..."
        Process.kill('HUP', -pgid)
        Process.detach(pgid)
        raise GalleryDL::GalleryDlTimeout
      ensure
        # puts "[PID:#{Process.pid}][TID:#{Thread.current.object_id}] deleting #{child_pid}.*"
        logger.debug "cleaning process dir #{`rm -fv #{processes_dir}/#{child_pid}.*`.inspect}"
        logger.debug "cleaning lockfile #{`rm -fv #{lockfile}`.inspect}"
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

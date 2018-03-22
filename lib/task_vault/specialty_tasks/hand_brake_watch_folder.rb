module TaskVault
  class HandBrakeWatchFolder < WatchFolder
    DISPOSITIONS = [:none, :move, :delete]

    DEFAULT_TYPES = [
      'mp4', 'mkv', 'avi', 'mpg', 'mpeg', 'rmvb', 'webm', 'flv',
      'qt', 'divx', 'asf', 'm4v', '3gp', 'ogv', 'mov', 'wmv'
    ]

    attr_ary_of String, :paths
    attr_dir :output, :move_to, mkdir: true
    attr_ary_of [String, Regexp], :filters, default: DEFAULT_TYPES.map { |ext| "*.#{ext}" }, add_rem: true, uniq: true
    attr_element_of DISPOSITIONS, :disposition, default: DISPOSITIONS.first
    attr_hash :arguments
    attr_int_between 0, nil, :failure_threshold, default: 1
    attr_int_between 0, nil, :status_interval, default: 15, allow_nil: true
    attr_hash :failures, protected_writer: true, default: Hash.new(0), serialize: false
    attr_of Object, :handbrake, default_proc: proc { HandBrake.prototype }, protected: true, serialize: false

    protected

    def simple_init(*args)
      require 'cli_chef' unless defined?(CLIChef::VERSION)
    end

    def process_file(file)
      output = generate_output_name(file)
      info("Starting encoding process: input: #{file} - output: #{output}")
      job = handbrake.encode(file, output, arguments)
      while job.running?
        info("#{file.file_name}: Percent #{job.percent}%  ETA #{job.eta.to_i.to_duration}  FPS #{job.fps}")
        0..status_interval.times do
          sleep(1) if job.running?
        end
      end
      if job.success?
        info("Encoding finished on #{file} in #{job.timer.latest.to_i.to_duration}")
        post_process(file)
      else
        warn("Encoding failed on #{file}: #{job.result.exit_code.description}")
        process_failure(file, output)
      end
    rescue => e
      error(e)
    end

    def post_process(file)
      case disposition
      when :delete
        info("Deleting file following successful encoding: #{file}")
        File.delete(file)
      when :move
        raise RunTimeError, "Disposition was set to move, but not move_to directory was set. Cannot proceed." unless move_to
        FileUtils.mkdir_p(move_to) unless Dir.exist?(move_to)
        output = "#{move_to}/#{file.file_name}"
        info("Moving original file following successful encoding of #{file}: #{output}")
        FileUtils.move(file, output)
      when :none
        # Nothing
      end
    end

    def process_failure(file, output)
      if File.exist?(output)
        info("Deleting partially completed encoding at #{output}")
        File.delete(output)
      end
      if (failures[file] += 1) >= failure_threshold
        warn("File #{file} has exceeded the maximum number of failures (#{failure_threshold}) and will not be attempted again.")
      else
        processed.delete(file)
      end
    end

    def generate_output_name(file)
      original = file.file_name(false)
      extension = (arguments.include?(:format) ? arguments[:format] : 'mp4')
      "#{output}/#{original}.#{extension}".pathify
    end
  end
end

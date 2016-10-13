module TaskVault

  class WatchFolder < Task

    attr_array_of String, :paths, add_rem: true, uniq: true, default: []
    attr_array_of String, :filter, add_rem: true, uniq: true, default: nil, allow_nil: true
    attr_int_between 0.001, nil, :interval, default: 5
    attr_bool :recursive, default: true
    attr_array :queue, default: []
    attr_array :processed, default: []
    attr_reader :processor

    alias_method :path, :paths
    alias_method :path=, :paths=
    alias_method :filters, :filter
    alias_method :filters=, :filter=

    protected

      def process_file file
        @processed.push(file)
        queue_msg("Doing nothing with #{file} because no one redefined me!", severity: :warn)
      end

      def run
        loop do
          start = Time.now

          files = @paths.map do |path|
            BBLib.scan_files( path, recursive: @recursive, filter: @filter ).map do |file|
              queue_file(file)
              file
            end
          end.flatten

          clear_processed(files)

          start_processor unless @queue.empty? || @processor && @processor.alive?

          sleep_time = @interval - (Time.now.to_f - start.to_f)
          sleep(sleep_time <= 0 ? 0 : sleep_time)
        end
      end

      def start_processor
        @processor = Thread.new {
          until @queue.empty?
            begin
              process_file(@queue.shift)
            rescue StandardError => e
              queue_msg(e, severity: :error)
            end
          end
        }
      end

      def clear_processed files
        @processed.each do |pr|
          unless files.include?(pr)
            @processed.delete(pr)
            queue_msg("File at '#{pr}' is no longer detected. Removing from processed list.", severity: :debug)
          end
        end
      end

      def queue_file file
        unless @queue.include?(file) || @processed.include?(file)
          @queue.push(file)
          queue_msg("New file detected for processing (in queue #{@queue.size}): #{file}", severity: :info)
        end
      end

      def setup_serialize
        serialize_method :paths, always: true
        serialize_method :filter, always: true
        serialize_method :interval, always: true
        serialize_method :recursive, always: true
        super
      end

  end

end

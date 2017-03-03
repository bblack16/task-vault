# frozen_string_literal: true
module TaskVault
  module Tasks
    class WatchFolder < Task
      attr_array_of String, :paths, add_rem: true, uniq: true, default: [], serialize: true, always: true
      attr_array_of String, :filter, add_rem: true, uniq: true, default: nil, allow_nil: true, serialize: true, always: true
      attr_int_between 0.001, nil, :interval, default: 5, serialize: true, always: true
      attr_bool :recursive, default: true, serialize: true, always: true
      attr_array :queue, default: []
      attr_array :processed, default: []
      attr_reader :processor

      alias path paths
      alias path= paths=
      alias filters filter
      alias filters= filter=

      add_alias(:watch_folder, :watchfolder)

      protected

      def process_file(file)
        @processed.push(file)
        queue_msg("Doing nothing with #{file} because no one redefined me!", severity: :warn)
      end

      def run
        queue_msg('Starting up watch folder...', severity: :info)
        loop do
          start = Time.now

          files = @paths.map do |path|
            BBLib.scan_files(path, *@filter, recursive: @recursive).map do |file|
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
        @processor = Thread.new do
          until @queue.empty?
            begin
              process_file(@queue.shift)
            rescue StandardError => e
              queue_msg(e, severity: :error)
            end
          end
        end
      end

      def clear_processed(files)
        @processed.each do |pr|
          unless files.include?(pr)
            @processed.delete(pr)
            queue_msg("File at '#{pr}' is no longer detected. Removing from processed list.", severity: :debug)
          end
        end
      end

      def queue_file(file)
        return if @queue.include?(file) || @processed.include?(file)
        @queue.push(file)
        queue_msg("New file detected for processing (in queue #{@queue.size}): #{file}", severity: :info)
      end
    end
  end
end

# frozen_string_literal: true
module TaskVault
  module Tasks
    class WatchFolder < Task
      attr_array_of String, :paths, add_rem: true, uniq: true, default: [], serialize: true, always: true
      attr_array_of String, :filter, add_rem: true, uniq: true, default: nil, allow_nil: true, serialize: true, always: true
      attr_int_between 0.001, nil, :interval, default: 5, serialize: true, always: true
      attr_bool :recursive, default: false, serialize: true, always: true
      attr_bool :track_processed, default: true, serialize: true, always: true
      attr_bool :full_details, default: false, serialize: true, always: true
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
        @processed.push(file.is_a?(String) ? file : file[:file]) if track_processed?
        queue_info(file, event: :file)
      end

      def file_removed(file)
        # Deal with a file vanishing if needed.
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
              process_file(next_file)
            rescue StandardError => e
              queue_msg(e, severity: :error)
            end
          end
        end
      end

      def next_file
        file = @queue.shift
        return file unless full_details?
        {
          file:       file,
          size:       File.size(file),
          modified:   File.mtime(file),
          changed:    File.ctime(file),
          accessed:   File.stat(file).atime,
          blocks:     File.stat(file).blocks,
          block_size: File.stat(file).blksize,
          full_size:  (File.stat(file).blocks * File.stat(file).blksize rescue nil),
          mode:       File.stat(file).mode,
          name:       file.file_name(false),
          dir:        File.dirname(file),
          extension:  File.extname(file)
        }
      end

      def clear_processed(files)
        @processed.each do |pr|
          unless files.include?(pr)
            @processed.delete(pr)
            queue_debug("File at '#{pr}' is no longer detected. Removing from processed list.")
            file_removed(pr)
          end
        end
      end

      def queue_file(file)
        return if @queue.include?(file) || @processed.include?(file)
        @queue.push(file)
        queue_debug("New file detected for processing (in queue #{@queue.size}): #{file}")
      end
    end
  end
end

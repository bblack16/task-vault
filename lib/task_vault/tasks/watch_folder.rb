module TaskVault
  class WatchFolder < Task
    attr_ary_of String, :paths, add_rem: true, uniq: true
    attr_ary_of [String, Regexp], :filters, add_rem: true, uniq: true
    attr_float :interval, default: 5
    attr_bool :recursive, default: false
    attr_bool :track_processed, default: true
    attr_ary :queue, :processed, serialize: false
    attr_of ::Proc, :processor, default: proc { |file| puts file }, arg_at: :block
    attr_of ::Proc, :removed_processor, default: nil, allow_nil: true
    attr_of Thread, :processing_thread, protected_writer: true

    protected

    def run(*args, &block)
      files = paths.flat_map do |path|
        BBLib.scan_files(path, *filters, recursive: recursive?) do |file|
          queue_file(file)
        end
      end

      clear_processed(files)
      start_processor
    end

    def queue_file(file)
      return file if queue.include?(file) || processed.include?(file)
      queue.push(file)
      debug("New file added for processing: #{file} (#{BBLib.plural_string(queue.size, 'file')} in queue)")
      start_processor
      file
    end

    def start_processor
      return if queue.empty? || processing_thread && processing_thread.alive?
      self.processing_thread = Thread.new do
        until queue.empty?
          begin
            process_file(queue.shift)
          rescue => e
            error(e)
          end
        end
      end
    end

    def process_file(file)
      debug("Now processing #{file}")
      processor.call(file, self)
    rescue => e
      error(e)
    ensure
      processed.push(file)
      debug("Finished processing #{file}")
    end

    def process_removal(file)
      debug("File #{file} has been removed from the #{BBLib.plural_string(paths.size, 'directory')}.")
      removed_processor.call(file) if removed_processor
    rescue => e
      error(e)
    ensure
      processed.delete(file)
    end

    def clear_processed(files)
      processed.each { |file| process_removal(file) unless files.include?(file) }
    end
  end
end

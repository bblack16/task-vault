module TaskVault

  class Logger < TaskVaultHandler

    attr_valid_dir :path, default: Dir.pwd
    attr_string :file_name, default: 'task_vault'
    attr_string :extension, default: 'log'
    attr_string :file_time_format, default: '.%y.%d'

    protected

      def process_message
        msg = read
        return nil unless severity_check(msg[:severity])
        "#{construct_msg(msg)}\n".to_file(log_file, mode: 'a')
      end

      def log_file
        [@path, "#{@file_name}#{Time.now.strftime(@file_time_format)}.#{@extension}"].join('/').pathify
      end

      def setup_serialize
        super
        serialize_method :path, always: true
        serialize_method :file_name, always: true
        serialize_method :extension, always: true
        serialize_method :file_time_format, always: true
      end

  end

end

# frozen_string_literal: true
module TaskVault
  module Handlers
    class Logger < TaskVaultHandler
      attr_dir :path, default: Dir.pwd, serialize: true, always: true
      attr_string :file_name, default: 'task_vault', serialize: true, always: true
      attr_string :extension, default: 'log', serialize: true, always: true
      attr_string :file_time_format, default: '.%Y.%d', serialize: true, always: true

      component_aliases(:logger)

      protected

      def process_message
        msg = read
        return nil unless severity_check(msg[:severity])
        "#{construct_msg(msg)}\n".to_file(log_file, mode: 'a')
      end

      def log_file
        [@path, "#{@file_name}#{Time.now.strftime(@file_time_format)}.#{@extension}"].join('/').pathify
      end
    end
  end
end

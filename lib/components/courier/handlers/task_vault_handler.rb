# frozen_string_literal: true
module TaskVault
  module Handlers
    class TaskVaultHandler < MessageHandler
      SEVERITIES = {
        fatal:   'FATAL',
        error:   'ERROR',
        warn:    'WARN ',
        info:    'INFO ',
        debug:   'DEBUG',
        verbose: 'VERBO',
        data:    'DATA'
      }.freeze

      attr_string :time_format, default: '%Y-%m-%d %H:%M:%S.%L', serialize: true, always: true
      attr_element_of SEVERITIES, :level, default: :debug, serialize: true, always: true

      add_alias(:default, :task_vault_handler, :stdout)

      protected

      def process_message
        msg = read
        return nil unless severity_check(msg[:severity])
        puts construct_msg(msg)
      end

      def construct_msg(msg)
        [
          build_time(msg[:time]),
          SEVERITIES[msg[:severity]] || 'UNKN ',
          msg[:component].to_s.sub('TaskVault::', '').sub('Tasks::', '').sub('Handlers::', ''),
          build_name(msg),
          build_message(msg[:msg])
        ].compact.join(' - ')
      end

      def build_time(time)
        (time.is_a?(Time) ? time : Time.now).strftime(@time_format)
      end

      def build_message(msg)
        if msg.is_a?(Exception)
          "#{msg}  -  #{msg.backtrace.join('  -  ')}"
        else
          msg.to_s
        end
      end

      def severity_check(severity)
        SEVERITIES.keys.find_index(severity) <= SEVERITIES.keys.find_index(@level)
      rescue
        true
      end

      def build_name(msg)
        return nil unless msg[:name]
        "#{msg[:name]}#{msg[:id] ? " (ID #{msg[:id]})" : nil}"
      end
    end
  end
end

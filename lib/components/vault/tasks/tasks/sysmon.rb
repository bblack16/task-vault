# frozen_string_literal: true



module TaskVault
  module Tasks
    class SysMon < Task
      attr_bool :system, :filesystems, :processes, default: true, serialize: true, always: true
      attr_int_between 0, nil, :retention, default: 5, serialize: true, always: true
      attr_float_between 5, nil, :interval, default: 60, serialize: true, always: true
      attr_hash :metrics, default: {}

      add_alias(:sysmon, :sys_mon)

      def refresh_metrics
        refresh_system if system?
        refresh_filesystems if filesystems?
        refresh_processes if processes?
      end

      def refresh_system
        metrics[:system] = BBLib::OS.system_stats
        queue_data(metrics[:system], event: :system)
      end

      def refresh_filesystems
        metrics[:filesystems] = BBLib::OS.filesystems
        queue_data(metrics[:filesystems], event: :filesystems)
      end

      def refresh_processes
        metrics[:processes] = BBLib::OS.processes
        queue_data(metrics[:processes], event: :processes)
      end

      protected

      def run
        loop do
          start = Time.now
          queue_verbose('Refreshing metrics...')
          refresh_metrics
          queue_verbose('Finished refreshing metrics.')
          sleep_time = @interval - (Time.now.to_f - start.to_f)
          sleep(sleep_time <= 0 ? 0 : sleep_time)
        end
      end

      def setup_routes
        get '/metrics' do
          metrics
        end

        get '/system' do
          metrics[:system]
        end

        get '/processes' do
          metrics[:processes]
        end

        get '/filesystems' do
          metrics[:filesystems]
        end
      end

    end
  end
end

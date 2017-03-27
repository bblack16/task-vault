# frozen_string_literal: true

require_relative 'alerts/_alerts'

module TaskVault
  module Tasks
    class SysMon < Task
      attr_bool :system, :filesystems, :processes, default: true, serialize: true
      attr_int_between 0, nil, :retention, default: 5, serialize: true
      attr_float_between 5, nil, :interval, default: 60, serialize: true
      attr_hash :metrics, default: {}
      attr_ary_of ProcessMonitor, :process_monitors, default: [], serialize: true
      attr_of NumericMonitor, :cpu_mon, defaults: nil, allow_nil: true, serialize: true

      add_alias(:sysmon, :sys_mon)

      def refresh_metrics
        refresh_system if system?
        refresh_filesystems if filesystems?
        refresh_processes if processes?
      end

      def refresh_system
        metrics[:system] = BBLib::OS.system_stats
        if cpu_mon
          cpu_mon.parent = self
          cpu_mon.name = 'CPU %'
          cpu_mon.check(metrics[:system][:cpu][:total])
        end
      end

      def refresh_filesystems
        metrics[:filesystems] = BBLib::OS.filesystems
      end

      def refresh_processes
        metrics[:processes] = BBLib::OS.processes
        process_monitors.each do |pm|
          pm.parent = self
          pm.check(*metrics[:processes])
        end
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

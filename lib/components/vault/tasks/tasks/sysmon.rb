# frozen_string_literal: true
module TaskVault
  module Tasks
    class SysMon < Task
      attr_bool :system, :filesystems, :processes, default: true, serialize: true, always: true
      attr_int_between 0, nil, :system_retention, default: 25, serialize: true, always: true
      attr_int_between 0, nil, :filesystems_retention, default: 10, serialize: true, always: true
      attr_int_between 0, nil, :processes_retention, default: 5, serialize: true, always: true
      attr_float_between 0, nil, :system_interval, default: 30, serialize: true, always: true
      attr_float_between 0, nil, :filesystems_interval, default: 120, serialize: true, always: true
      attr_float_between 0, nil, :processes_interval, default: 60, serialize: true, always: true
      attr_hash :metrics, default: {}, serialize: false
      attr_bool :cache, :send_aggregations, default: true, serialize: true, always: true
      attr_int :minimum_aggregations, default: 3, serialize: true, always: true

      component_aliases(:sysmon, :sys_mon)

      def refresh_system
        metrics[:system] = BBLib::OS.system_stats
        add_to_cache(:system) if cache?
        queue_data(metrics[:system], event: :system)
        queue_data(metrics[:system][:cpu], event: :cpu)
        queue_data(metrics[:system][:memory], event: :memory)
        queue_data(metrics[:system][:uptime], event: :uptime)
        return unless send_aggregations? && metrics_cache[:system].size >= minimum_aggregations
        queue_data(system_aggregation, event: :system_aggregation)
      end

      def system_aggregation
        hash = metrics_cache[:system].to_a.last.last.dup
        ['cpu.total', 'cpu.user', 'cpu.system', 'cpu.nice', 'cpu.idle', 'cpu.wait',
          'memory.used', 'memory.free', 'memory.free_p', 'memory.used_p']. each do |path|
          hash = hash.hpath_set(path => aggregations_for(:system, path))
        end
        hash
      end

      def refresh_filesystems
        metrics[:filesystems] = BBLib::OS.filesystems
        add_to_cache(:filesystems) if cache?
        queue_data(metrics[:filesystems], event: :filesystems)
        metrics[:filesystems].each do |filesystem|
          queue_data(filesystem, event: :filesystem)
        end
        return unless send_aggregations? && metrics_cache[:filesystems].size >= minimum_aggregations
        fs_agg = filesystems_aggregation
        fs_agg.each do |fs|
          queue_data(fs, event: :filesystem_aggregation)
        end
        queue_data(fs_agg, event: :filesystems_aggregation)
      end

      def filesystems_aggregation
        metrics_cache[:filesystems].values.last.map do |fs|
          hash = fs.dup
          fs_ary = metrics_cache[:filesystems].values.map { |v| v.find { |f| BBLib::OS.windows? ? f[:drive] == fs[:drive] : fs[:mount] == f[:mount] } }.compact
          ['free', 'used', 'free_p', 'used_p']. each do |path|
            hash = hash.hpath_set(path => aggregations_for(fs_ary, path))
          end
          hash
        end
      end

      def refresh_processes
        metrics[:processes] = BBLib::OS.processes
        add_to_cache(:processes) if cache?
        queue_data(metrics[:processes], event: :processes)
        metrics[:processes].each do |process|
          queue_data(process, event: :process)
        end
        return unless send_aggregations? && metrics_cache[:processes].size >= minimum_aggregations
        procs = processes_aggregation
        procs.each do |pr|
          queue_info(pr, event: :process_aggregation)
        end
        queue_data(procs, event: :processes_aggregation)
      end

      def processes_aggregation
        metrics_cache[:processes].values.last.map do |pr|
          hash = pr.dup
          p_ary = metrics_cache[:processes].values.map { |v| v.find { |f| pr[:pid] == f[:pid] } }.compact
          ['memory', 'cpu']. each do |path|
            hash = hash.hpath_set(path => aggregations_for(p_ary, path))
          end
          hash
        end
      end

      def aggregations_for(type, path, limit: nil)
        return nil unless type.is_a?(Array) || metrics_cache[type] && !metrics_cache[type].empty?
        if type.is_a?(Array)
          numbers = type.map { |metric| metric.hpath(path).first }.select { |n| n.is_a?(Numeric) }
        else
          numbers = metrics_cache[type]&.map { |_t, metric| metric.hpath(path).first }.select { |n| n.is_a?(Numeric) }
        end
        return nil if numbers.empty?
        numbers = numbers[-limit..-1] if limit && numbers.size > limit
        sum = numbers.inject(0) { |s, x| s += x }
        {
          max:      numbers.max,
          min:      numbers.min,
          avg:      sum / numbers.size.to_f,
          sum:      sum,
          newest:   numbers.last,
          oldest:   numbers.first,
          previous: numbers[-2],
          count:    numbers.size,
          delta:    numbers.size == 1 ? numbers.last : (numbers[-1] - numbers[-2] rescue nil),
          all:      numbers
        }
      end

      protected

      def add_to_cache(type)
        (metrics_cache[type] ||= {})[Time.now] = metrics[type]
        metrics_cache[type].shift until metrics_cache[type].size <= send("#{type}_retention")
      end

      def metrics_cache
        @metrics_cache ||= {}
      end

      def run_times
        @run_times ||= { system: Time.now, filesystems: Time.now, processes: Time.now }
      end

      def run
        loop do
          start = Time.now
          queue_verbose('Refreshing metrics...')
          next_time = []
          [:system, :filesystems, :processes].each do |type|
            next unless send("#{type}?")
            next_time << run_times[type] if run_times[type] > Time.now
            next unless run_times[type] <= Time.now
            queue_verbose("About to refresh #{type}.")
            send("refresh_#{type}")
            run_times[type] = Time.now + send("#{type}_interval")
            next_time << run_times[type]
          end
          queue_verbose('Finished refreshing metrics.')
          sleep_time = next_time.min.to_f - Time.now.to_f
          sleep(sleep_time <= 0 ? 0 : sleep_time)
        end
      end

      def setup_routes
        super

        get '/metrics' do
          metrics
        end

        get '/system' do
          if system?
            metrics[:system]
          else
            { status: 404, message: 'System monitoring is disabled on this SysMon' }
          end
        end

        get '/system/aggregations' do
          if system?
            system_aggregation
          else
            { status: 404, message: 'System monitoring is disabled on this SysMon' }
          end
        end

        get '/processes' do
          if processes?
            metrics[:processes]
          else
            { status: 404, message: 'Process monitoring is disabled on this SysMon' }
          end
        end

        get '/processes/aggregations' do
          if processes?
            processes_aggregation
          else
            { status: 404, message: 'Process monitoring is disabled on this SysMon' }
          end
        end

        get '/filesystems' do
          if filesystems?
            metrics[:filesystems]
          else
            { status: 404, message: 'Filesystem monitoring is disabled on this SysMon' }
          end
        end

        get '/filesystems/aggregations' do
          if filesystems?
            filesystems_aggregation
          else
            { status: 404, message: 'Filesystem monitoring is disabled on this SysMon' }
          end
        end

        get '/cache' do
          metrics_cache
        end
      end

    end
  end
end

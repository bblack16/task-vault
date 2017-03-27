module TaskVault
  module Tasks
    class ProcessMonitor < Alert

      OPERATORS = {
        eq:  'equal to',
        gt:  'greater than',
        gte: 'greater than or equal to',
        lt:  'less than',
        lte: 'less than or equal to',
        not: 'not equal to'
      }

      attr_of [String, Regexp], :name, :cmdline, default: nil, allow_nil: true, serialize: true
      attr_int :count, default: nil, serialize: true, allow_nil: true
      attr_element_of [:up, :down], :state, default: :down, serialize: true
      attr_element_of OPERATORS.keys, :operator, default: :gte, serialize: true
      attr_str :start, default: nil, allow_nil: true, serailize: true
      attr_bool :kill, default: true, serialize: true, allow_nil: true

      def describe
        search = [name.is_a?(Regexp) ? name.inspect : name, cmdline.is_a?(Regexp) ? cmdline.inspect : cmdline].compact.join(' ')
        "Monitors processes" +
        (name ? " with a name #{name.is_a?(Regexp) ? "that matches #{name.inspect}" : "equal to #{name}"}#{cmdline ? ' and' : nil}" : '') +
        (cmdline ? " with a cmdline #{cmdline.is_a?(Regexp) ? "that matches #{cmdline.inspect}" : "equal to #{cmdline}"}" : '') +
        (count ? " for a total of unique pids #{OPERATORS[operator]} #{count}" : '' ) +
        ". If the process is #{state} " +
        if state == :down && start
          "the following command will be run: #{start}."
        elsif state == :up && kill?
          "all matching processes will be killed."
        else
          "messages are sent."
        end
      end

      def event_key(details)
        [name.is_a?(Regexp) ? name.inspect : name, cmdline.is_a?(Regexp) ? cmdline.inspect : cmdline].compact.join('_').to_sym
      end

      def check(*processes)
        parent&.queue_info(describe)
        return nil unless name || cmdline
        matches = processes.find_all do |process|
          compare(process[:name], name) && compare(process[:cmd], cmdline)
        end

        if count
          if check_count
            send_alert(count: matches.size)
          else
            send_clear(count: matches.size)
          end
        elsif state == :up && !matches.empty?
          send_alert
          matches.each do |m|
            parent&.queue_warn("About to kill #{m[:name]} with pid of #{m[:pid]}.")
            Process.kill('KILL', m[:pid])
          end
        elsif state == :down && matches.empty?
          send_alert
          parent&.queue_warn("Attempting to restart now using #{start}.")
          start_process
        else
          send_clear
        end
      end

      def compare(a, b)
        return true unless b
        if b.is_a?(Regexp)
          a =~ b
        else
          a == b
        end
      end

      def start_process
        spawn(start)
      end

      def check_count(num)
        case operator
        when :eq
          num == count
        when :not
          num != count
        when :gt
          num > count
        when :gte
          num >= count
        when :lt
          num < count
        when :lte
          num <= count
        end
      end

    end
  end
end

module TaskVault
  module Tasks
    class NumericMonitor < Alert

      OPERATORS = {
        eq:  'equal to',
        gt:  'greater than',
        gte: 'greater than or equal to',
        lt:  'less than',
        lte: 'less than or equal to',
        not: 'not equal to'
      }

      attr_str :name, default: '', serialize: true
      attr_str :message, default: '{{hostname}}: {{name}} is {{operator}} {{threshold}} ({{value}})', serialize: true
      attr_int :threshold, default: 0, serialize: true
      attr_element_of OPERATORS.keys, :operator, default: :eq, serialize: true

      def describe
        "Checks #{name}. Alerts are sent when #{name} is #{OPERATORS[operator]} #{threshold}."
      end

      def event_key(details = {})
        name
      end

      def check(num)
        if _check(num)
          send_alert(value: num, name: name)
        else
          send_clear(value: num, name: name)
        end
      end

      protected

      def _check(num)
        case operator
        when :eq
          num == threshold
        when :not
          num != threshold
        when :gt
          num > threshold
        when :gte
          num >= threshold
        when :lt
          num < threshold
        when :lte
          num <= threshold
        end
      end

    end
  end
end

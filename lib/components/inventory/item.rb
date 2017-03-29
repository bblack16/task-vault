module TaskVault
  class Inventory < ServerComponent
    class Item < BBLib::LazyClass
      attr_str :key, serialize: true
      attr_hash :description, default: [], serialize: true
      attr_of Object, :value, default: nil, serialize: true
      attr_of Time, :expiration, default: nil, allow_nil: true, serialize: true
      attr_int :access_counter, default: 0
      attr_of Time, :last_accessed, default: Time.now

      after :_default_key, :lazy_init
      after :access_update, :value

      alias_method :item, :value
      alias_method :item=, :value=

      def details
        serialize.merge(
          access_count: access_counter,
          last_accessed: last_accessed,
          expiration: expiration,
          item_class: @value.class.to_s
        )
      end

      def fits?(params)
        return false unless params.is_a?(Hash)
        params.all? do |k, param|
          if k == :class
            compare(param, @value.class)
          else
            compare(param, description[k])
          end
        end
      end

      def compare(a, b)
        case [a.class]
        when [Regexp]
          a =~ b.to_s
        when [String]
          a.to_s == b.to_s
        else
          a == b
        end
      end

      def expired?
        return false if expiration.nil?
        Time.now <= expiration
      end

      protected

      def access_update
        self.access_counter += 1
        self.last_accessed = Time.now
      end

      def _default_key
        self.key = generate_key unless key
      end

      def generate_key
        SecureRandom.hex(10)
      end

    end
  end
end

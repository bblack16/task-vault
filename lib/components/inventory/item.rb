module TaskVault
  class Inventory < ServerComponent
    class Item
      include BBLib::Effortless

      attr_str :key, serialize: true
      attr_hash :description, default: {}, serialize: true, always: true
      attr_of Object, :value, default: nil, serialize: true, always: true
      attr_of Time, :expiration, default: nil, allow_nil: true, serialize: true, always: true
      attr_int :access_counter, default: 0, serialize: false
      attr_of Time, :last_accessed, default: Time.now, serialize: false
      attr_bool :locked, default: false, serialize: true, always: true
      attr_ary_of Class, :allowed_classes, default: nil, serialize: true, always: true

      after :simple_init, :_default_key
      after :value, :access_update

      alias_method :item, :value
      alias_method :item=, :value=

      def value=(val)
        raise ArgumentError, 'This item is locked!' if locked?
        raise ArgumentError, "Wrong class type #{val.class}. This item is class locked to #{allowed_classes.join(', ')}." unless allowed_classes.nil? || allowed_classes.any? { |c| val.is_a?(c) }
        @value = val
      end

      def details
        serialize.merge(
          access_count: access_counter,
          last_accessed: last_accessed,
          expiration: expiration,
          item_class: value.class.to_s
        )
      end

      def fits?(params)
        return false unless params.is_a?(Hash)
        params.all? do |k, param|
          if k == :class
            compare(param, value.class)
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

      def is_a?(klass)
        value.is_a?(klass) || super
      end

      protected

      def simple_init(*args)
        BBLib.named_args(*args).each do |k, v|
          next if respond_to?(k)
          description[k] = v
        end
      end

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

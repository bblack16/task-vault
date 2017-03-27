module TaskVault
  module Tasks
    class Validator < BBLib::LazyClass
      OPERATORS = [:eq, :gt, :gte, :lt, :lte, :starts, :ends, :contains, :matches, :included, :exist].freeze

      attr_element_of OPERATORS, :operator, default: :eq, serialize: true
      attr_str :path, require: true, serialize: true
      attr_bool :invert, default: false, serialize: true
      attr_of Object, :value, require: true, serialize: true

      def compare(hash)
        match = case operator
        when :eq
          retrieve(hash).first == value
        when :gt
          retrieve(hash).first > value
        when :gte
          retrieve(hash).first >= value
        when :lt
          retrieve(hash).first < value
        when :lte
          retrieve(hash).first <= value
        when :starts
          retrieve(hash).first.to_s.starts_with?(value)
        when :ends
          retrieve(hash).first.to_s.ends_with?(value)
        when :contains
          retrieve(hash).first.include?(value)
        when :matches
          retrieve(hash).first =~ value
        when :included
          value.include?(retrieve(hash).first)
        when :exists
          !retrieve(hash).empty?
        else
          false
        end
        invert? ? !match : match
      rescue => e
        p "ERROR: #{e}"
        false
      end

      def retrieve(hash)
        hash.respond_to?(:hpath) ? hash.hpath(path) : (path == '' ? hash : [] )
      end

    end
  end
end

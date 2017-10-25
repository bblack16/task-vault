module TaskVault
  module Tasks
    class Rest < Task
      METHODS = [:get, :post, :put, :delete, :patch, :head].freeze

      attr_str :path, default: nil, allow_nil: true, serialize: true, always: true
      attr_element_of METHODS, :http_method, default: :get, serialize: true, always: true
      attr_hash :headers, default: {}, serialize: true, always: true
      attr_str :payload, default: nil, allow_nil: true, serialize: true, always: true, pre_proc: proc { |x| x.is_a?(Hash) ? x.to_json : x }
      attr_of RestClient::Resource, :client, serialize: false

      component_aliases(:rest, :rest_call, :restcall)

      def url
        full_client.to_s
      end

      def full_client
        return client unless path
        client[path]
      end

      protected

      def simple_init(*args)
        super
        named = BBLib.named_args(*args)
        return unless named.include?(:url)
        self.client = RestClient::Resource.new(named[:url], (named[:options] || {}))
      end

      def run
        queue_debug("About to run #{http_method} request against #{url}")
        run_call
      end

      def build_opts
        case http_method
        when :post, :put, :patch
          [payload, headers]
        else
          [headers]
        end
      end

      def run_call
        result = full_client.send(http_method, *build_opts) { |response, _rq, _rs| response }
        queue_debug("Got back a response of #{result.code}.")
        process_result(result)
      rescue => e
        queue_error(e)
      end

      # Redefine this method in subclasses to do things with callback results.
      def process_result(result)
        queue_data(result.body, event: :result, response: result)
      end
    end
  end
end

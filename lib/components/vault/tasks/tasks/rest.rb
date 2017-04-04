module TaskVault
  module Tasks
    class Rest < Task
      METHODS = [:get, :post, :put, :delete]
      PROTOCOLS = [:http, :https]
      attr_str :host, default: 'localhost', serialize: true, always: true
      attr_str :path, default: nil, allow_nil: true, serialize: true, always: true
      attr_element_of PROTOCOLS, :protocol, default: :http, serialize: true, always: true
      attr_element_of METHODS, :http_method, default: :get, serialize: true, always: true
      attr_int :port, default: nil, allow_nil: true, serialize: true, always: true
      attr_hash :headers, default: nil, allow_nil: true, serialize: true, always: true
      attr_str :payload, default: nil, allow_nil: true, serialize: true, always: true, pre_proc: proc { |x| x.is_a?(Hash) ? x.to_json : x }
      attr_hash :options, default: {}, serialize: true, always: true

      component_aliases(:rest, :rest_call, :restcall)

      def url
        "#{protocol}://#{host}:#{port}/#{path}"
      end

      def url=(url)
        self.protocol = url.scan(/^https?/i).first&.downcase&.to_sym || :http
        url = "#{protocol}://#{url}" unless url.downcase.start_with?(protocol.to_s)
        self.host = url.scan(/https?\:\/\/(.*?)[\/:]|https?\:\/\/(.*?)$/i).flatten.compact.first
        self.port = (url.scan(/#{Regexp.quote(host)}:(\d+)/).flatten.first&.to_i || nil rescue nil)
        self.path = url.scan(/#{Regexp.quote(host)}#{port ? ":#{port}" : ''}\/?(.*)/i).flatten.first
        url
      rescue => e
        raise ArgumentError, "Unable to parse url: #{url}"
      end

      protected

      def run
        queue_debug("About to run #{http_method} request against #{url}")
        run_call
      end

      def build_opts
        hash = {
          method: http_method,
          url: url
        }
        hash[:headers] = headers if headers
        hash[:payload] = payload if payload
        hash.merge(options)
      end

      def run_call
        result = RestClient::Request.execute(build_opts) { |response, _rq, _rs| response }
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

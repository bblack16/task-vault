module TaskVault
  module Tasks
    class ElasticsearchQuery < Task
      attr_str :host, default: 'localhost', serialize: true, always: true
      attr_str :index, :type, default: nil, allow_nil:true, serialize: true, always: true
      attr_element_of [:http, :https], :protocol, default: :http, serialuze: true, always: true
      attr_int :port, default: 9200, serialize: true, always: true
      attr_str :user, :pass, default: nil, allow_nil: true, serialize: true
      attr_ary_of Hash, :queries, default: [], serialize: true, add_rem: true

      add_alias(:elasticsearch_query, :elasticsearch_qry)

      def connected?
        RestClient.get(base_url)
        true
      rescue => e
        queue_error(e)
        false
      end

      protected

      def base_url
        "#{protocol}://#{user ? "#{user}:#{pass}@" : nil}#{host}:#{port}"
      end

      def search_url
        "#{base_url}/#{index ? "#{index}/#{type ? "#{type}/" : nil}" : nil}_search"
      end

      def run
        queue_debug("About to run queries. I have a total of #{queries.size} #{BBLib.pluralize(queries.size, 'quer', 'ies', 'y')} to run against #{host}.")
        queries.each do |query|
          run_query(query)
        end
      end

      def run_query(query)
        result = JSON.parse(RestClient.post(search_url, query.to_json).body)
        process_result(result, query)
      rescue => e
        queue_error(e)
      end

      # Redefine this method in subclasses to do things with query results.
      def process_result(result, query)
        queue_debug("Found a total of #{results.hpath('..hits.total').first} results for #{BBLib.chars_up_to(query, 50, '..')}.")
        queue_data(result, event: :result, query: query)
      end

      def setup_routes
        get '/queries' do
          queries
        end

        post '/add_query' do
          request.body.rewind
          add_queries(JSON.parse(request.body.read))
        end

        delete '/delete/:id' do
          queries.delete(params[:id].to_i)
        end
      end
    end
  end
end

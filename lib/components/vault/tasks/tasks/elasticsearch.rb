module TaskVault
  module Tasks
    class Elasticsearch < Task
      attr_str :index, :type, default: nil, allow_nil: true, serialize: true, always: true
      attr_ary_of Hash, :queries, default: [], serialize: true, add_rem: true
      attr_bool :cache, default: false, serialize: true, always: true
      attr_int :cache_limit, default: 5, serialize: true, always: true
      attr_of RestClient::Resource, :client

      component_aliases(:elasticsearch, :elasticsearch_query)

      def connected?
        client.get(url)
        true
      rescue => e
        queue_error(e)
        false
      end

      def result_cache
        @result_cache ||= {}
      end

      protected

      def search_url
        "/#{index ? "#{index}/#{type ? "#{type}/" : nil}" : nil}_search"
      end

      def run
        queue_debug("About to run queries. I have a total of #{queries.size} queries to run against #{host}.")
        queries.each do |query|
          run_query(query)
        end
      end

      def run_query(query)
        result = JSON.parse(client.post(search_url, query.to_json).body)
        cache_result(result) if cache?
        process_result(result, query)
      rescue => e
        queue_error(e)
      end

      def cache_result(result)
        result_cache[Time.now] = result
        result_cache.shift until result_cache.size <= cache_limit
      end

      # Redefine this method in subclasses to do things with query results.
      def process_result(result, query)
        count = result.hpath('hits.total').first
        queue_debug("Found a total of #{count} #{BBLib.pluralize(count, 'result')} for #{BBLib.chars_up_to(query, 50, '..')}.")
        queue_data(result, event: :result, query: query)
        queue_data(result.hpath('hits.hits').first, event: :hits, query: query)
        result.hpath('hits.hits').first.each do |hit|
          queue_data(hit, event: :hit, query: query)
        end
        queue_data(result['aggregations'], event: :aggregations, query: query)
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

        get '/latest' do
          result_cache.to_a.last.last rescue {}
        end

        get '/cache' do
          result_cache
        end
      end
    end
  end
end

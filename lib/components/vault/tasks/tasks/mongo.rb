
Mongo::Logger.logger.level = ::Logger::FATAL

module TaskVault
  module Tasks
    class MongoDB < Task
      attr_ary_of Hash, :queries, default: [], serialize: true, add_rem: true
      attr_sym :collection, default: nil, allow_nil: true, serialize: true
      attr_of Mongo::Client, :db

      component_aliases(:mongo, :mongodb, :mongo_db)

      def connected?
        return false unless db
        db.list_databases
        true
      rescue => e
        queue_error("Error connecting to the cluster: #{e}; #{e.backtrace.join('; ')}")
        false
      end

      protected

      def lazy_init(*args)
        super
        named = BBLib.named_args(*args)
        return unless named.include?(:hosts) && named.include?(:database) || named.include?(:uri)
        if named.include?(:uri)
          self.db = Mongo::Client.new(named[:uri])
        else
          self.db = Mongo::Client.new([named[:hosts]].flatten, database: named[:database])
        end
      end

      def run
        queue_debug("About to run queries. I have #{queries.size} quer#{queries.size == 1 ? 'y' : 'ies'} to run against #{collection}.")
        queries.each do |query|
          run_query(query)
        end
      end

      def run_query(query)
        process_result(db[collection].find(query), query)
      end

      # Redefine this method in subclasses to do things with query results.
      def process_result(results, query)
        queue_debug("Found a total of #{results.count} results for #{query.to_s[0..49]}...")
        queue_data(results, event: :results) if event_handled?(:results)
        results.each do |result|
          queue_data(result, event: :result)
        end
      end

      def msg_metadata
        {
          collection: collection,
          database:   db.database
        }.merge(super)
      end

      def setup_routes
        super
        get '/db' do
          {
            connected:  connected?,
            database:   db.database,
            collection: collection,
            client:     db
          }
        end

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

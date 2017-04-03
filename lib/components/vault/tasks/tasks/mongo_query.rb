module TaskVault
  module Tasks
    class MongoQuery < Task
      attr_ary_of String, :hosts, default: ['127.0.0.1:27017'], serialize: true
      attr_str :database, default: 'task_vault', serialize: true
      attr_ary_of Hash, :queries, default: [], serialize: true, add_rem: true
      attr_sym :collection, default: nil, allow_nil: true, serialize: true
      attr_reader :db

      component_aliases(:mongo_query, :mongo_qry, :mongoquery, :mongoqry)

      def connected?
        return false unless @db
        @db.list_databases
        true
      rescue => e
        queue_msg("Error connecting to the cluster: #{e}; #{e.backtrace.join('; ')}")
        false
      end

      protected

      def setup_client(force = false)
        return unless force || database && !hosts.empty?
        return if connected?
        @db = inventory&.find(class: Mongo::Client, hosts: hosts, database: database) || new_client
      end

      def new_client
        Mongo::Logger.logger.level = ::Logger::FATAL
        client                     = Mongo::Client.new(hosts, database: database)
        client.logger.level        = ::Logger::FATAL
        queue_msg("MongoDB client created for '#{database}' on #{hosts.join(', ')}.", severity: :info)
        inventory&.store(item: client, description: { hosts: hosts, database: database }) if use_inventory?
        client
      end

      def run
        setup_client(true)
        queue_debug("Spinning up query running agent. I have #{queries.size} quer#{queries.size == 1 ? 'y' : 'ies'} to run against #{collection}.")
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
          database: database
        }.merge(super)
      end

      def setup_routes
        get '/db' do
          {
            connected:  connected?,
            database:   database,
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

# frozen_string_literal: true
module TaskVault
  module Tasks
    class SqlQuery < Task
      attr_ary_of String, :host, default: 'localhost', serialize: true, always: true
      attr_int :port, default: 5672, serialize: true, always: true
      attr_str :user, :pass, default: 'guest', serialize: true, always: true
      attr_str :database, default: :task_vault, serialize: true, always: true
      attr_str :adapter, default: :sqlite, serialize: true, always: true
      attr_hash :options, default: {}, serialize: true, always: true
      attr_ary_of String, :queries, default: [], serialize: true, always: true
      attr_element_of [:array, :dataset], :format, default: :array, serialize: true, always: true
      attr_reader :db

      add_alias(:sql_query, :sql_qry)

      def connected?
        db.tables
        true
      rescue => e
        false
      end

      protected

      # Redefine this method in subclasses. The default version just queues the message in TaskVault
      def process_message(msg, info, properties)
        queue_data(msg, event: :message, info: info, properties: properties)
        # Remeber to ack the message if manual_ack is used
        acknowledge(delivery_info.delivery_tag) if options[:manual_ack]
      end

      def run
        connect
        queue_debug("Starting up. About to run #{queries.size} #{BBLib.pluralize(queries.size, 'quer', 'ies', 'y')}.")
        queries.each do |query|
          result = db.fetch(query)
          result = result.to_a if format == :array
          process_result(result, query)
        end
      end

      def process_result(result, query)
        queue_data(query, event: :query)
        queue_data(result, event: :result)
      end

      def connect_opts
        {
          adapter:  adapter,
          host:     host,
          port:     port,
          user:     user,
          password: pass,
          database: database
        }.reject { |k, v| v.nil? }.merge(options)
      end

      def connect
        return if @db && connected?
        @db = inventory&.find(connect_opts.merge(class: /Sequel.*Database/)) || new_db
      rescue => e
        queue_fatal(e)
      end

      def new_db
        @db = Sequel.connect(connect_opts)
        inventory&.store(item: @db, description: connect_opts)
        @db
      end

    end
  end
end

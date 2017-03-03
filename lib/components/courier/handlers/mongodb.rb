# frozen_string_literal: true
module TaskVault
  module Handlers
    class MongoDB < MessageHandler
      ACTIONS = [:auto, :insert, :update, :update_many, :delete, :delete_many].freeze

      attr_bool :message_only, default: true, serialize: true
      attr_ary_of String, :hosts, default: ['127.0.0.1:27017'], serialize: true
      attr_str :database, default: 'task_vault', serialize: true
      attr_element_of ACTIONS, :default_action, default: :auto, allow_nil: true, serialize: true
      attr_sym :default_collection, default: nil, allow_nil: true, serialize: true
      attr_ary_of [Symbol, String], :default_lookups, :ignore_fields, default: [], serialize: true
      attr_reader :db

      # after :setup_client, :hosts=, :database=

      add_alias(:mongo, :mongodb, :mongo_db)

      protected

      def run
        setup_client(true)
        super
      end

      def process_message
        msg        = read
        collection = msg[:collection] || default_collection
        action     = msg[:action] || default_action
        record     = build_msg(msg)
        return unless collection && action && !action.to_s.empty?
        case action
        when :auto
          process_auto(collection, generate_query(record, msg[:lookups] || default_lookups), record)
        when :insert
          insert_doc(collection, record)
        when :update
          update_doc(collection, generate_query(msg), record)
        when :update_many
          update_many_docs(collection, generate_query(msg), record)
        when :delete
          delete_doc(collection, generate_query(record, msg[:lookups] || default_lookups))
        when :delete_many
          delete_many_docs(collection, generate_query(record, msg[:lookups] || default_lookups))
        else
          queue_msg("Unknown action type sent '#{action}'. Allowed types are #{ACTIONS.join(', ')}.", severity: :warn)
        end
      rescue => e
        queue_msg("There was an error processing a message. message = #{record.to_s[0..49]}..., error = #{e}; #{e.backtrace}", severity: :error)
      end

      def generate_query(record, lookups)
        lookups.map { |l| [l, record[l]] }.to_h
      end

      def update_doc(collection, query, record)
        queue_msg("About to update a record in #{collection} matching #{query}: #{record.to_s[0..50]}...", severity: :debug)
        db[collection].update_one(query, record)
        queue_msg("Updated record in #{collection} that matched #{query}. Record: #{record.to_s[0..50]}...", severity: :debug)
      end

      def update_many_docs(collection, query, record)
        queue_msg("About to update all records in #{collection} matching #{query}: #{record.to_s[0..50]}...", severity: :debug)
        count = db[collection].update_many(query, record).modified_count
        queue_msg("Updated #{count} record#{count == 1 ? nil : 's'} in #{collection} that matched #{query}. Record: #{record.to_s[0..50]}...", severity: :debug)
      end

      def insert_doc(collection, record)
        queue_msg("About to insert new record into #{collection}: #{record.to_s[0..50]}...", severity: :debug)
        db[collection].insert_one(record)
        queue_msg("Inserted record into #{collection}: #{record.to_s[0..50]}...", severity: :debug)
      end

      def delete_doc(collection, query)
        queue_msg("About to delete a record in #{collection} matching #{query}", severity: :debug)
        count = db[collection].delete_one(query).deleted_count
        queue_msg("Deleted #{count} record#{count  == 1 ? nil : 's'} in #{collection} matching #{query}", severity: :debug)
      end

      def delete_many_docs(collection, query)
        queue_msg("About to delete any records in #{collection} matching #{query}", severity: :debug)
        count = db[collection].delete_many(query).deleted_count
        queue_msg("Deleted #{count} record#{count  == 1 ? nil : 's'} in #{collection} matching #{query}", severity: :debug)
      end

      def process_auto(collection, query, record)
        queue_msg("Checking to see if document exists matching #{query}", severity: :debug)
        if !query.empty? && doc_exists?(collection, query)
          update_doc(collection, query, record)
        else
          insert_doc(collection, record)
        end
      end

      def doc_exists?(collection, query)
        !db[collection].find(query).limit(1).first.nil?
      end

      IGNORE_FIELDS = [:collection, :action, :lookups]

      def build_msg(msg)
        msg = msg.reject { |k, v| IGNORE_FIELDS.include?(k) || ignore_fields.include?(k) }
        msg = msg[:msg] if message_only?
        msg = JSON.parse(msg.to_s) unless msg.is_a?(Hash) || msg.is_a?(Array)
        msg
      end

      def setup_client(force = false)
        return unless force || database && !hosts.empty?
        Mongo::Logger.logger.level = ::Logger::FATAL
        @db = Mongo::Client.new(hosts, database: database)
        db.logger.level = ::Logger::FATAL
        queue_msg("MongoDB client created for '#{database}' on #{hosts.join(', ')}.", severity: :info)
        db.list_databases
      rescue => e
        queue_msg("Error connecting to the cluster: #{e}; #{e.backtrace.join('; ')}")
      end
    end
  end
end

# frozen_string_literal: true
require 'rest-client'

module TaskVault
  module Handlers
    class REST < MessageHandler
      METHODS   = [:post, :put, :get, :delete, :update]
      PROTOCOLS = [:http, :https]
      FORMATS   = [:json, :yaml, :string, :object]

      attr_bool :message_only, default: true, serialize: true
      attr_str :host, default: 'localhost', serialize: true
      attr_int :port, default: 1234, serialize: true
      attr_str :uri, default: '/', serialize: true
      attr_bool :message_only, default: false, serialize: true
      attr_bool :log_response, default: true, serailize: false
      attr_ary_of [String, Symbol], :include_fields, :exclude_fields, default: nil, allow_nil: true, serialize: true
      attr_element_of METHODS, :default_method, default: :post, serialize: true
      attr_element_of PROTOCOLS, :default_protocol, default: :http, serialize: true
      attr_element_of FORMATS, :default_format, default: :json, serialize: true
      attr_hash :options, default: {}, serialize: true
      attr_hash :default_headers, default: {}, serialize: true

      component_aliases(:rest, :rest_client, :webhook)

      protected

      def process_message
        msg = read
        response = RestClient::Request.execute(
          options.merge(
            url: build_url(msg),
            method: msg[:rest_method] || default_method,
            payload: build_msg(msg),
            headers: default_headers.merge(msg[:rest_headers] || {})
          )
        )
        queue_msg(response.body) if log_response?
      rescue => e
        queue_msg("There was an error sending/processing a message. message = #{msg.to_s[0..49]}..., error = #{e}; #{e.backtrace}", severity: :error)
      end

      def build_msg(msg)
        if message_only?
          doc = msg[:msg]
        elsif exclude_fields.nil? && include_fields
          doc = msg.reject { |k, v| !include_fields.include?(k) }
        elsif exclude_fields
          doc = msg.reject { |k, v| exclude_fields.include?(k) && (include_fields.nil? || include_fields.include?(k)) }
        else
          doc = msg
        end

        case (msg[:format] || default_format)
        when :json
          doc.to_json
        when :yaml
          doc.to_yaml
        when :string
          doc.to_s
        else
          doc
        end
      end

      def build_url(msg)
        return msg[:rest_url] if msg[:rest_url]
        "#{msg[:rest_protocol] || default_protocol}://#{msg[:rest_host] || host}:#{msg[:rest_port] || port}#{msg[:rest_uri] || uri}"
      end
    end
  end
end

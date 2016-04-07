require 'socket'
require_relative 'overseer'

class TaskVault

  class Sentry < Component
    attr_reader :mode, :port

    def mode= m
      raise ArgumentError, "Invalid Sentry mode '#{m}'. Options are #{MODES.join(', ')}" unless MODES.include?(m)
      @mode = m
      restart if running?
    end

    def port= port
      @port = port.to_i
      restart if running?
    end

    protected

      MODES = [:tcp, :udp]

      def setup_defaults
        self.port = 2016
        self.mode = :tcp
      end

      def init_thread
        send("init_#{@mode}".to_sym)
      end

      def init_tcp
        @thread = Thread.new {
          begin
            server = TCPServer.new(@port)
            queue_msg("INFO - Sentry is up and listening to TCP on port #{@port}.")
            loop do
              Thread.start(server.accept) do |client|
                sock_domain, remote_port, remote_hostname, remote_ip = client.peeraddr
                msg = client.gets
                overseer = Overseer.new(@parent)
                result = overseer.handle_request(msg)
                client.puts result.to_json
                if result[:erorr].nil?
                  queue_msg("DEBUG - Sentry spotted a reqest from #{remote_hostname} (#{remote_ip}) and fulfilled it.", :default)
                else
                  queue_msg("WARN - Sentry spotted a reqest from #{remote_hostname} (#{remote_ip}) and failed to process it. First 150 chars of error: #{result[:error][0..149]}", :default)
                end
                client.close
              end
            end
          rescue StandardError, Exception => e
            queue_msg(e)
            e
          end
        }
      end

      def init_udp
        @thread = Thread.new {
          begin
            server = UDPSocket.new
            server.bind('localhost', @port)
            queue_msg("INFO - Sentry is up and listening to UDP on port #{@port}.")
            loop do
              text, sender = s.recvfrom(16)
              queue_msg(text, sender:sender)
            end
          rescue StandardError, Exception => e
            queue_msg(e)
            e
          end
        }
      end
  end

end

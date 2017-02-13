module TaskVault

  class Beacon < ServerComponent
    attr_int :port, default: 2017, serialize: true, always: true
    attr_hash :connections, default: {}

    def start
      queue_msg('Starting up component.', severity: :info)
      super
    end

    def stop
      queue_msg('Stopping component.', severity: :info)
      super
    end

    protected

    def run
      begin
        server = TCPServer.new(@port)
        loop do
          Thread.start(server.accept) do |client|
            begin
              client.puts( handle_request(client) )
            rescue StandardError => e
              queue_msg('An error occured while talking to a client', severity: :error)
              queue_msg(e, severity: :error)
            ensure
              client.close
            end
          end
        end
      rescue StandardError => e
        queue_msg(e, severity: :fatal)
      end
    end

    def handle_request request
      remote_ip = client.peeraddr[3]
      msg = JSON.parse(client.recv(1000000000))
      register_connection(msg, remote_ip)
    end

    def registry_connection(msg, ip)
      connections["#{ip}:#{msg[:port]}"] = msg
    end

  end

end

require 'socket'

class TaskVault

  class Pipboy
    attr_accessor :host, :port, :socket, :verbose

    def initialize host = 'localhost', port = 2016, verbose: false
      @external_methods = nil
      load_instance_methods
      self.host = host
      self.port = port
      self.verbose = verbose
    end

    def connect
      @socket = TCPSocket.open(@host, @port)
    end

    def close
      @socket.close if defined?(@socket)
    end

    def add_task task = nil, **args
      send_request( :vault, :queue, **(task.nil? ? args : task.serialize) )
    end

    def methods
      (@external_methods.keys.sort + super())
    end

    def method_missing *args, **named
      if methods.include?(args.first)
        eargs = @external_methods[args.delete_at(0)]
        send_request(eargs.first, eargs.last, *args, **named)
      else
        super(*args, **named)
      end
    end

    protected

      def load_instance_methods
        @external_methods = Hash.new
        ignore, pignore, duplicates = Object.instance_methods, Pipboy.instance_methods, Array.new
        {
          TaskVault => [:task_vault, nil],
          Vault => [:vault],
          TaskQueue => [:vault],
          Workbench => [:workbench],
          Courier => [:courier],
          Protectron => [:protectron],
          Sentry => [:sentry]
          # MessageHandler => :message_handler # Not sure how this will get supported yet, currently it works by using the name of the hanlder as the object is a send_request call
        }.each do |cls, obj|
          cls.instance_methods.each do |mtd|
            next if ignore.include?(mtd)
            # clean_name = cls.to_s.split('::').last
            # clean_name[0] = clean_name[0].downcase
            # clean_name = clean_name.chars.map{ |c| c.downcase == c ? c : ('_' + c) }.join.downcase.to_sym
            if  @external_methods.include?(mtd) || pignore.include?(mtd) || duplicates.include?(mtd)
              @external_methods["#{obj.last}#{obj.last ? '_' : nil}#{mtd}".to_sym] = [obj.first, obj.last, mtd]
              old = @external_methods.delete mtd
              @external_methods["#{old[1]}#{old[1] ? '_' : nil}#{mtd}".to_sym] = old if old
              duplicates.push mtd
            else
              @external_methods[mtd] = [obj.first, obj.last, mtd]
            end
          end
        end
      end

      def send_request object, method, *args, **named

        connect
        multi = named.delete(:multi) if named
        argument = (named.nil? ? {} : named).merge({args:args})
        request = {object => { method => argument } }
        @socket.puts request.to_json
        result = JSON.parse(@socket.gets).keys_to_sym rescue result
        close
        if !@verbose
          !multi ? result[:requests].first[:response] : result[:requests].map{|r| r[:response] }
        else
          result
        end
      end

  end

end

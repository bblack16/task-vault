class TaskVault

  class TaskTemplate
    attr_reader :name, :defaults

    def initialize name, description = '', **arguments
      @name = name
      @description = description
      @defaults = Hash.new
      arguments.each do |k,v|
        add k, v
      end
    end

    def add key, value
      @defaults[key] = value
    end

    def save path
      serialize.to_json.to_file("#{path}/#{@name}.template".pathify, mode: 'w')
    end

    def serialize
      {
        name: @name,
        description: @description,
        defaults: @defaults
      }
    end

    def self.load path
      if File.exists?(path)
        data = JSON.parse(File.read(path)).keys_to_sym
        TaskTemplate.new(data[:name], data[:description], **data[:defaults])
      else
        raise "File '#{path}' does not exist. Template could not be loaded."
      end
    end

  end

end

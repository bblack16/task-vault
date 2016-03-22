

module TaskVault

  class DynamicTask
    attr_reader :name

    def initialize name
      self.name = name
    end

    def name= n
      @name = n.to_s
    end

    def generate_tasks
      raise "This method is abstract and should have been overwritten"
    end

    def serialize
      BBLib.to_hash(self).hash_path_set('class' => self.class.to_s)
    end

  end

end

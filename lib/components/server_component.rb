# frozen_string_literal: true
module TaskVault
  class ServerComponent < Component

    def root
      parent
    end

    def self.description
      'No description yet...'
    end

    def description
      self.class.description
    end

  end
end

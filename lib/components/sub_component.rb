# frozen_string_literal: true
module TaskVault
  class SubComponent < Component

    def root
      parent.parent if parent
    end

    def describe
      serialize.merge(history: history[0..9].map { |h| "#{h[:time]} - #{h[:severity].to_s.upcase} - #{h[:msg]}" })
    end

    def self.aliases
      @aliases ||= []
    end

    def self.add_alias(*aliases)
      aliases.each do |a|
        clean = a.to_s.downcase.to_sym
        self.aliases << clean unless self.aliases.include?(clean)
      end
    end

    def self.load(data, parent: nil, namespace: TaskVault)
      if data.is_a?(Hash)
        desc = descendants
        unless desc.any? { |d| d.to_s == data[:class].to_s }
          match = desc.find { |d| d.aliases.include?(data[:class].to_s.downcase.to_sym) }
          data[:class] = match.to_s if match
        end
      end
      super
    end

  end
end

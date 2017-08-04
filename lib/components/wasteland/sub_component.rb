
module TaskVault
  class SubComponent < Component

    class << self
      def base_route(api, version = 1)
        "#{api ? "/api/v#{version}" : nil}/components/:component/:subcomponent/:id"
      end
    end

    # def slim(view, *args)
    #   @route_delegate.send(:slim, "components/#{parent.class.to_s.gsub('::', '_')}/#{self.class.to_s.downcase.split('::').last}/#{view}".to_sym, *args)
    # end

  end
end

module BBLib
  module Attr

    def attr_handlers(*methods, **opts)
      methods.each do |m|
        attr_type(m, opts, &attr_set(m, opts) do |*x|
          x.flatten.flat_map do |handler|
            if handler.is_a?(Hash)
              handler
            elsif handler.is_a?(TaskVault::MessageHandler)
              handler.serialize
            else
              handler.to_s.to_sym
            end
          end
        end)
        attr_array_adder(m, Symbol, Hash, **opts) if opts[:adder] || opts[:add_rem]
        attr_array_remover(m, Symbol, Hash, **opts) if opts[:remover] || opts[:add_rem]
        _register_attr(m, :handler, opts)
      end
    end

  end
end

module BBLib
  module Attrs

    def attr_handlers(*methods, **opts)
      methods.each do |method|
        attr_custom(method, opts) do |*x|
          x.flatten.flat_map do |handler|
            if handler.is_a?(Hash)
              handler
            elsif handler.is_a?(TaskVault::MessageHandler)
              handler.serialize
            else
              handler.to_s.to_sym
            end
          end
        end
        attr_array_adder(method, opts[:adder_name]) if opts[:adder] || opts[:add_rem]
        attr_array_remover(method, opts[:remover_name]) if opts[:remover] || opts[:add_rem]
      end
    end

  end
end

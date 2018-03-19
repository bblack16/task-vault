module TaskVault
  class Proc < Task

    attr_of ::Proc, :proc, required: true, arg_at: :block

    protected

    def simple_init(*args)
      extend PutsOverride unless BBLib.named_args(*args).include?(:no_puts_override)
    end

    def run(*args, &block)
      self.proc.call
    end
  end
end

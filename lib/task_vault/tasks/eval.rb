module TaskVault
  class Eval < Task

    attr_str :evaluation, required: true, arg_at: 0

    extend PutsOverride

    protected

    def run(*args, &block)
      eval(evaluation)
    end
  end
end

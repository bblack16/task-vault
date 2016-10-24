
module TaskVault

  class EvalTask < Task

    attr_str :evaluation, default: '', serialize: true, always: true

    alias_method :code=, :evaluation=
    alias_method :code, :evaluation

    protected

      def run
        eval(@evaluation)
      end

  end

end

# frozen_string_literal: true
module TaskVault
  class EvalTask < Task
    attr_str :evaluation, default: '', serialize: true, always: true

    alias code= evaluation=
    alias code evaluation

    protected

    def run
      eval(@evaluation)
    end
  end
end

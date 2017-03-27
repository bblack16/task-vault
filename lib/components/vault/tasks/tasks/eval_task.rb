# frozen_string_literal: true
module TaskVault
  module Tasks
    class EvalTask < Task
      attr_str :evaluation, default: '', serialize: true, always: true

      alias code= evaluation=
      alias code evaluation

      add_alias(:eval, :eval_task)

      protected

      def lazy_init(*args)
        extend PutsQueue unless named.include?(:no_puts)
        super
      end

      def run
        eval(@evaluation)
      end
    end
  end
end

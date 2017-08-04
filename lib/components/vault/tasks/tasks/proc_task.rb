# frozen_string_literal: true
module TaskVault
  module Tasks
    class ProcTask < Task
      attr_of Proc, :proc, required: true, serialize: true, always: true

      component_aliases(:proc, :proc_task)

      protected

      def simple_init(*args)
        extend PutsQueue unless BBLib.named_args(*args).include?(:no_puts)
        super
      end

      def run
        @proc.call
      end
    end
  end
end

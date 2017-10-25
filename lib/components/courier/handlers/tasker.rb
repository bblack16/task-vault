# frozen_string_literal: true
module TaskVault
  module Handlers
    class Tasker < MessageHandler
      attr_hash :task_args, default: {}, serialize: true, always: true, to_serialize_only: true
      attr_str :arg_path, default: 'value', serialize: true, always: true
      attr_of TaskVault::Vault, :vault, default: nil, allow_nil: true

      component_aliases(:tasker)

      protected

      def process_message
        msg = read[:msg]
        hash = task_args.dup.hpath_set(arg_path => msg)
        _vault.add(hash)
      rescue => e
        queue_error(e)
      end

      def _vault
        vault || root.components_of(TaskVault::Vault).first
      end

    end
  end
end

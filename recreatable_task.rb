# frozen_string_literal: true

module TaskQueue
  # Mixin included by Tasks that may be recreated from a file.
  module RecreatableTask
    def self.included(base)
      base.send(:include, InstanceMethods)
    end

    # Add this as instance methods.
    module InstanceMethods
      # This method is the base execution unit for a given Task, it
      # receives a Hash-like parameter collection defined by the
      # `params_to_hash` resultant Hash.
      def run!(params)
        # no-op
      end

      # This method is intended to provide a nice Hash-based interface
      # for all the parameters used in a given task and, that in case
      # of system failure, might be recreated later.
      # For this reason, user has to take in mind that the hash should
      # always be serializable right away.
      def params_to_hash
        {}
      end

      def to_task
        task = Task.new(work_block: proc { run!(params_to_hash) })
        task.recreatable = true
        task.recreatable.freeze # Avoid further mutations on this.
        task.recreatable_class = self.class
        task.recreatable_class.freeze
        task.recreatable_params = params_to_hash
        task.recreatable_params.freeze
        task
      end
    end
  end
end

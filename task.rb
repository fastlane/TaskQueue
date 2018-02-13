module TaskQueue
  # Smallest unit of work that can be submitted to a TaskQueue
  # Not reusable, if you attempt to re-execute this, the worker will raise an exception
  class Task
    attr_accessor :name
    attr_accessor :description
    attr_accessor :work_block
    attr_accessor :ensure_block
    attr_accessor :completed
    attr_accessor :submitted

    def initialize(name: nil, description: nil, work_block: nil, ensure_block: nil)
      self.work_block = work_block
      self.ensure_block = ensure_block
      self.name = name
      self.description = description

      self.name.freeze
      self.description.freeze
      self.completed = false
      self.submitted = false
    end
  end
end

# frozen_string_literal: true
require 'json'
require_relative 'recreatable_task'

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
    attr_accessor :finished_successfully
    attr_accessor :recreatable
    attr_accessor :recreatable_class
    attr_accessor :recreatable_params

    def initialize(name: nil, description: nil, work_block: nil, ensure_block: nil)
      self.work_block = work_block
      self.ensure_block = ensure_block
      self.name = name
      self.description = description

      self.name.freeze
      self.description.freeze
      self.recreatable = false
      self.recreatable_class = nil
      self.completed = false
      self.submitted = false
      self.finished_successfully = false
    end

    def self.from_recreatable_task!(file_path: nil)
      raise 'Task file path was not provided' if file_path.nil?
      raise 'Task class was not provided' if recreatable_subclass.nil?

      recreatable_task_hash = JSON.parse(File.read(file_path))
      recreatable_task = recreatable_task_hash['class'].constantize.new

      raise 'Recreatable task does not include `RecreatableTask` module' unless recreatable_task.class.include?(RecreatableTask)

      params = recreatable_task_hash['params']

      raise "Unexpected parameter type, found #{params.class} expected Hash." unless params.is_a?(Hash)

      task = Task.new(work_block: proc { recreatable_task.run!(params) })
      task.recreatable = true
      task.recreatable.freeze # Avoid further mutations on this.
      task.recreatable_class = recreatable_task.constantize
      task.recreatable_class.freeze
      task.recreatable_params = params
      task.recreatable_params.freeze

      task
    end
  end
end

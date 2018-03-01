# frozen_string_literal: true

require 'set'
require 'tmpdir'
require 'json'
require 'pathname'
require_relative 'task'
require_relative 'queue_worker'
require_relative 'recreatable_task'

module TaskQueue
  # A queue that executes tasks in the order in which they were received
  class TaskQueue
    attr_reader :name

    def initialize(name:, number_of_workers: 1)
      @name = name
      @queue = Queue.new
      @available_workers = Set.new
      @busy_workers = Set.new
      @worker_list_mutex = Mutex.new
      @queue_mutex = Mutex.new

      number_of_workers.times do |_n|
        worker = QueueWorker.new(worker_delegate: self)
        @available_workers.add(worker)
      end

      ObjectSpace.define_finalizer(self, self.class.finalizer(name: name, number_of_workers: number_of_workers, tasks: @queue))

      start_task_distributor
    end

    def worker_completed_task(worker:)
      @worker_list_mutex.synchronize do
        # remove worker from busy list
        @busy_workers.delete(worker)
        # add this worker back the available worker pool
        @available_workers.add(worker)
      end
      # wake up task distributor if it's asleep
      @task_distributor_thread.wakeup
    end

    def available_worker
      @worker_list_mutex.synchronize do
        worker = @available_workers.first
        return nil if worker.nil?
        # remove worker from available pool
        @available_workers.delete(worker)

        # add this worker to the busy pool
        @busy_workers.add(worker)
        return worker
      end
    end

    def hand_out_work
      # get first available worker
      while (worker = available_worker)
        # if none are available, that's cool.
        break if worker.nil?

        # grab the next task, if no task, then this current thread will suspend until there is
        task = @queue.pop

        # assign it to the free worker
        worker.process(task: task)
      end
    end

    def start_task_distributor
      start_task_distributor_ready = false
      @task_distributor_thread = Thread.new do
        Thread.abort_on_exception = true

        start_task_distributor_ready = true
        Thread.stop
        loop do
          hand_out_work
          # only sleep if we have no workers or the queue is empty
          Thread.stop if @available_workers.count.zero? || @queue.empty?
        end
      end

      until start_task_distributor_ready
        # Spin until the start_task_distributor is in sleeping state
        sleep(0.0001)
      end
    rescue StandardError => ex
      puts(ex)
      raise ex if Thread.abort_on_exception || Thread.current.abort_on_exception
    end

    def add_task_async(task:)
      task.submitted = true

      @queue << task
      @task_distributor_thread.wakeup
    end

    def task_count
      @queue.length
    end

    def busy_worker_count
      @worker_list_mutex.synchronize do
        return @busy_workers.count
      end
    end

    def self.finalizer(name: nil, number_of_workers: 1, tasks: nil)
      proc {
        return if tasks.nil? || name.nil?
        tasks = tasks.size.times.map { tasks.pop }
        return if tasks.count.zero?
        recreatable_tasks = tasks.select { |task| task.recreatable && !task.completed }
        return if recreatable_tasks.count.zero?
        name = name.sub(' ', '_')
        temp_dir = Pathname.new(Dir.tmpdir).join(name)
        FileUtils.mkdir_p(temp_dir) unless File.directory?(temp_dir)
        FileUtils.rm_rf("#{temp_dir}/.", secure: true)
        meta_path = temp_dir.join('meta.json')
        FileUtils.touch(meta_path)
        File.write(meta_path, JSON.pretty_generate(:name => name, :number_of_workers => number_of_workers))
        recreatable_tasks
          .each_with_index do |task, index|
            task_meta = { :class => task.recreatable_class.name, :params => task.recreatable_params }
            FileUtils.touch(temp_dir.join("#{index}.json"))
            File.write(temp_dir.join("#{index}.json"), JSON.pretty_generate(task_meta))
          end
      }
    end

    # Factory method.
    # Creates a new TaskQueue given the name of the TaskQueue that was destroyed.
    #
    # @param name: String
    # @returns [TaskQueue] with its recreatable tasks already added async.
    def self.from_recreated_tasks!(name: nil)
      return nil if name.nil?
      name = name.sub(' ', '_')
      path = Pathname.new(Dir.tmpdir).join(name, 'meta.json')
      return unless File.file?(path)
      queue_meta = JSON.parse(File.read(path), symbolize_names: true)
      queue = TaskQueue.new(name: queue_meta[:name].sub('_', ' '), number_of_workers: queue_meta[:number_of_workers])
      Dir[Pathname.new(Dir.tmpdir).join('test_queue', '*.json')].sort.each do |json_file|
        next if File.basename(json_file).eql?('meta.json') # Skip meta file
        queue.add_task_async(task: Task.from_recreatable_task!(file_path: Pathname.new(Dir.tmpdir).join(name, json_file)))
      end
      queue
    end
  end
end

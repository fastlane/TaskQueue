require "set"
require_relative "task"
require_relative "queue_worker"

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
      while (worker = self.available_worker)
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
          Thread.stop if @available_workers.count == 0 || @queue.empty?
        end
      end

      until start_task_distributor_ready
        # Spin until the start_task_distributor is in sleeping state
        sleep(0.0001)
      end
    rescue ex
      puts(ex)
      raise ex
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
  end
end

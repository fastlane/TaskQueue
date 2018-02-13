require 'securerandom'
module TaskQueue
  # Class responsible for executing a single task
  # Designed to live as long as the owning queue lives
  class QueueWorker
    attr_reader :id

    def eql?(other)
      id == other.id
    end

    def hash
      id.hash
    end

    def busy
      @busy_mutex.synchronize do
        return @busy
      end
    end

    def initialize(worker_delegate:)
      @id = SecureRandom.uuid
      @busy_mutex = Mutex.new
      @worker_delegate = worker_delegate
      @busy = false
    end

    def process(task:)
      @busy_mutex.synchronize do
        raise "unable to process task:#{task.name}, we're already processing #{@current_task.name}" if @busy
        raise "unable to process task:#{task.name}, it already completed" if task.completed
        raise "unable to process task:#{task.name}, no work_block included" if task.work_block.nil?

        @busy = true
        @current_task = task
      end

      Thread.new do
        Thread.abort_on_exception = true
        # Start work
        work_block = @current_task.work_block
        @current_task.work_block = nil

        work_block.call

        # When work is done, set @busy to false so we can be assigned up a new work unit
        @busy_mutex.synchronize do
          @busy = false
          @current_task.completed = true
          @current_task.completed.freeze # Sorry, you can't run this task again
          puts "Worker completed #{id}"
          @worker_delegate.worker_completed_task(worker: self)
        end
      end
    ensure
      task.ensure_block.call if task.ensure_block
    end
  end
end

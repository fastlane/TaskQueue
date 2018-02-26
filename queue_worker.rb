require "securerandom"
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

    def finish_task
      # Alright, set everything completed
      @busy_mutex.synchronize do
        @busy = false
        @current_task.completed = true
        @current_task.completed.freeze # Sorry, you can't run this task again
        @current_task.finished_successfully = true
        @current_task.finished_successfully.freeze
      end

      begin
        # if we have an ensure block to run, run it now
        unless @current_task.ensure_block.nil?
          case @current_task.ensure_block.arity
            when 0
              @current_task.ensure_block.call
            when 1
              @current_task.ensure_block.call(@current_task.finished_successfully)
            else
              raise "Unexpected number of arguments in `ensure_block`, expected 1 or 2, got #{@current_task.ensure_block.arity}"
          end
        end
        @current_task.ensure_block.call if @current_task.ensure_block
      rescue StandardError => e
        # Oh noes, our ensure block raised something
        puts("finish_task failed with exception: #{e.message}")
        puts(e.backtrace.map { |line| "  #{line}" })

        raise if Thread.abort_on_exception || Thread.current.abort_on_exception
      ensure
        # lastly, we can finally make sure this worker gets reassigned some work
        @busy_mutex.synchronize do
          @current_task = nil
          @worker_delegate.worker_completed_task(worker: self)
        end
      end
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
        begin
          Thread.abort_on_exception = true
          # Start work
          work_block = @current_task.work_block
          @current_task.work_block = nil

          work_block.call

          # When work is done, set @busy to false so we can be assigned up a new work unit
          finish_task
        rescue StandardError => e
          if @busy
            finish_task
          end

          puts("Thread terminated with exception: #{e.message}")
          puts(e.backtrace.map { |line| "  #{line}" })

          raise e if Thread.abort_on_exception || Thread.current.abort_on_exception
        end
      end
    end
  end
end

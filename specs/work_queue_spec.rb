require_relative "../task_queue"

class MockRecreatableTask
  include TaskQueue::RecreatableTask

  def run!(**params)
    puts params.to_s
  end

  def params_to_hash
    { one_param: "Hello", other_param: "World" }
  end
end

class MockOrderedRecreatableTask
  include TaskQueue::RecreatableTask

  attr_accessor :number
  def initialize(number: nil)
    self.number = number
  end

  def run!(**params)
    puts params.to_s
  end

  def params_to_hash
    { one_param: "Hello", other_param: "World", number: number }
  end
end

module TaskQueue
  describe TaskQueue do
    def wait_for_task_to_complete(task: nil)
      sleep 0.001 until task.completed
    end

    it 'Executes one block of work with just 1 worker' do
      queue = TaskQueue.new(name: 'test queue')
      work_completed = false
      task = Task.new(work_block: proc { work_completed = true })
      queue.add_task_async(task: task)
      wait_for_task_to_complete(task: task)
      expect(work_completed).to be(true)
    end

    it 'Executes ensure block' do
      queue = TaskQueue.new(name: 'test queue')
      work_completed = false
      ensured = false
      task = Task.new(work_block: proc { work_completed = true }, ensure_block: proc { ensured = true })
      queue.add_task_async(task: task)
      wait_for_task_to_complete(task: task)
      expect(work_completed).to be(true)
      expect(ensured).to be(true)
    end

    it 'Executes ensure block on exception' do
      ensured = false
      expect {
        queue = TaskQueue.new(name: 'test queue')
        task = Task.new(work_block: proc { raise "Oh noes" }, ensure_block: proc { ensured = true })
        queue.add_task_async(task: task)
        wait_for_task_to_complete(task: task)
      }.to raise_error(RuntimeError)

      expect(ensured).to be(true)
    end

    it 'Reports success state when task completed without exceptions' do
      queue = TaskQueue.new(name: 'test queue')
      work_completed = false
      success_task = false
      task = Task.new(work_block: proc { work_completed = true }, ensure_block: proc { |success| success_task = true })
      queue.add_task_async(task: task)
      wait_for_task_to_complete(task: task)
      expect(work_completed).to be(true)
      expect(success_task).to be(true)
      expect(task.finished_successfully).to be(true)
    end

    it 'Reports unsuccess state when task completed with exceptions' do
      ensured = false
      success_task = nil
      expect {
        queue = TaskQueue.new(name: 'test queue')
        task = Task.new(work_block: proc { raise "Oh noes" }, ensure_block: proc { |success| ensured = true; success_task = success })
        queue.add_task_async(task: task)
        wait_for_task_to_complete(task: task)

        expect(task.finished_successfully).to be(false)
      }.to raise_error(RuntimeError)

      expect(ensured).to be(true)
      expect(success_task).to be(false)
    end

    it 'Executes 2 blocks of work with just 1 worker' do
      queue = TaskQueue.new(name: 'test queue')

      work_completed1 = false
      work_completed2 = false

      task1 = Task.new(work_block: proc do work_completed1 = true end)
      task2 = Task.new(work_block: proc do work_completed2 = true end)
      queue.add_task_async(task: task1)
      queue.add_task_async(task: task2)

      wait_for_task_to_complete(task: task1)
      wait_for_task_to_complete(task: task2)

      expect(work_completed1).to be(true)
      expect(work_completed2).to be(true)
    end

    it 'Executes 2 blocks of work with 2 workers' do
      queue = TaskQueue.new(name: 'test queue', number_of_workers: 2)

      work_completed1 = false
      work_completed2 = false

      task1 = Task.new(work_block: proc do work_completed1 = true end)
      task2 = Task.new(work_block: proc do work_completed2 = true end)
      queue.add_task_async(task: task1)
      queue.add_task_async(task: task2)

      wait_for_task_to_complete(task: task1)
      wait_for_task_to_complete(task: task2)

      expect(work_completed1).to be(true)
      expect(work_completed2).to be(true)
    end

    it 'Executes 1000 blocks of work with 1 worker, in serial' do
      queue = TaskQueue.new(name: 'test queue')

      numbers = []
      expected_results = []
      # count from 0 to 9999
      1000.times { |i| expected_results << i }

      tasks = expected_results.map do |number|
        # Task that when executed appends the current number to the `numbers` array
        # This should be done in sequence
        Task.new(work_block: proc do numbers << number end)
      end

      tasks.each { |task| queue.add_task_async(task: task) }
      tasks.each { |task| wait_for_task_to_complete(task: task) }

      # expect count from 0 to 9999 for both arrays since we're in serial mode
      expect(numbers).to eq(expected_results)
    end

    it 'Executes 1000 blocks of work with 10 workers' do
      queue = TaskQueue.new(name: 'test queue', number_of_workers: 10)

      numbers = []
      expected_results = []
      # count from 0 to 9999
      1000.times { |i| expected_results << i }

      tasks = expected_results.map do |number|
        Task.new(work_block: proc do numbers << number end)
      end

      tasks.each { |task| queue.add_task_async(task: task) }
      tasks.each { |task| wait_for_task_to_complete(task: task) }
    end

    it 'Executes 50 blocks of work with 2 workers' do
      queue = TaskQueue.new(name: 'test queue', number_of_workers: 3)

      numbers = []
      expected_results = []
      # count from 0 to 50
      50.times { |i| expected_results << i }

      tasks = expected_results.map do |number|
        Task.new(work_block: proc do numbers << number end)
      end

      tasks.each { |task| queue.add_task_async(task: task) }
      tasks.each { |task| wait_for_task_to_complete(task: task) }

      # expect that the arrays aren't equal because this was async
      expect(numbers).to_not eq(expected_results)
    end

    it 'Creates tasks from any RecreatableTask' do
      recreatable_task = MockRecreatableTask.new
      task = recreatable_task.to_task
      expect(task).to_not be_nil
    end

    it 'Should execute tasks from RecreatableTasks' do
      recreatable_task = MockRecreatableTask.new
      task = recreatable_task.to_task
      queue = TaskQueue.new(name: 'test queue')
      expect(STDOUT).to receive(:puts).with(recreatable_task.params_to_hash.to_s)
      queue.add_task_async(task: task)
      wait_for_task_to_complete(task: task)
    end
    context 'it should call its destructor' do
      it 'Should call finalizer when the Queue is destroyed' do
        # creating pipe for IPC to get result from child process
        # after it garbaged
        # http://ruby-doc.org/core-2.0.0/IO.html#method-c-pipe
        rd, wr = IO.pipe

        # forking
        # https://ruby-doc.org/core-2.1.2/Process.html#method-c-fork
        if fork
          wr.close
          called = rd.read
          Process.wait
          expect(called).to eq({ 'name' => 'test queue', 'number_of_workers' => 1 }.to_s)
          rd.close
        else
          rd.close
          # overriding TaskQueue.finalizer(...)
          TaskQueue.singleton_class.class_eval do
            define_method(:finalizer) do |arg|
              proc {
                wr.write({ 'name' => arg[:name], 'number_of_workers' => arg[:number_of_workers] })
                wr.close
              }
            end
          end

          queue = TaskQueue.new(name: 'test queue')
          queue = nil
          GC.start
        end
      end
    end

    it 'Stores in JSON format the meta information of the queue' do
      queue = TaskQueue.new(name: 'test queue')
      tasks = Queue.new
      # We need at least one pending task to let the queue be stored
      tasks << MockRecreatableTask.new.to_task
      allow(queue).to receive(:queue).and_return(tasks)
      TaskQueue.finalizer(name: 'test queue', number_of_workers: 1, tasks: tasks).call
      meta_path = Pathname.new(Dir.tmpdir).join('test_queue', 'meta.json')
      expect(File.exist?(meta_path)).to eq(true)
      queue_meta = JSON.parse(File.read(meta_path), symbolize_names: true)
      expect(queue_meta).to eq({ name: 'test_queue', number_of_workers: 1 })

      # Cleanup directory
      FileUtils.rm_rf(Pathname.new(Dir.tmpdir).join('test_queue'), secure: true)
    end

    it 'Stores the correct number of pending tasks' do
      queue = TaskQueue.new(name: 'test queue')
      tasks = Queue.new
      # We need at least one pending task to let the queue be stored
      task_number = 10
      task_number.times do
        tasks << MockRecreatableTask.new.to_task
      end

      allow(queue).to receive(:queue).and_return(tasks)
      TaskQueue.finalizer(name: 'test queue', number_of_workers: 1, tasks: tasks).call

      file_count = Dir[Pathname.new(Dir.tmpdir).join('test_queue', '*.json')].select { |file| File.file?(file) }.count

      expect(file_count).to eq(task_number + 1) # Task count plus meta file.

      # Cleanup directory
      FileUtils.rm_rf(Pathname.new(Dir.tmpdir).join('test_queue'), secure: true)
    end

    it 'Stores the correct information of pending tasks in order to recreate them' do
      queue = TaskQueue.new(name: 'test queue')
      tasks = Queue.new
      # We need at least one pending task to let the queue be stored
      tasks << MockRecreatableTask.new.to_task

      allow(queue).to receive(:queue).and_return(tasks)
      TaskQueue.finalizer(name: 'test queue', number_of_workers: 1, tasks: tasks).call
      Dir[Pathname.new(Dir.tmpdir).join('test_queue', '*.json')].select { |file| File.file?(file) }.each do |json_file|
        next if File.basename(json_file).eql?('meta.json') # Skip meta file
        task_hash = JSON.parse(File.read(json_file), symbolize_names: true)
        expect(task_hash).to eq({ class: MockRecreatableTask.to_s, params: { one_param: "Hello", other_param: "World" } })
      end

      # Cleanup directory
      FileUtils.rm_rf(Pathname.new(Dir.tmpdir).join('test_queue'), secure: true)
    end

    it 'Recreates correctly the task from the information stored' do
      queue = TaskQueue.new(name: 'test queue')
      tasks = Queue.new
      # We need at least one pending task to let the queue be stored
      tasks << MockRecreatableTask.new.to_task

      allow(queue).to receive(:queue).and_return(tasks)
      TaskQueue.finalizer(name: 'test queue', number_of_workers: 1, tasks: tasks).call
      Dir[Pathname.new(Dir.tmpdir).join('test_queue', '*.json')].select { |file| File.file?(file) }.each do |json_file|
        next if File.basename(json_file).eql?('meta.json') # Skip meta file
        recreatable_task = Task.from_recreatable_task!(file_path: json_file)
        expect(recreatable_task.recreatable_class).to eq(MockRecreatableTask)
        expect(recreatable_task.recreatable_params).to eq({ one_param: "Hello", other_param: "World" })
      end

      # Cleanup directory
      FileUtils.rm_rf(Pathname.new(Dir.tmpdir).join('test_queue'), secure: true)
    end

    it 'Recreates the whole TaskQueue from the information stored' do
      queue = TaskQueue.new(name: 'test queue')
      tasks = Queue.new
      # We need at least one pending task to let the queue be stored
      task_number = 2
      task_number.times do
        tasks << MockRecreatableTask.new.to_task
      end

      allow(queue).to receive(:queue).and_return(tasks)
      TaskQueue.finalizer(name: 'test queue', number_of_workers: 1, tasks: tasks).call

      expect(STDOUT).to receive(:puts).with({ one_param: "Hello", other_param: "World" }.to_s).twice
      recreated_queue = TaskQueue.from_recreated_tasks!(name: 'test queue')
      sleep 0.001 until recreated_queue.task_count.zero?
      expect(recreated_queue.name).to eq('test queue')

      # Cleanup directory
      FileUtils.rm_rf(Pathname.new(Dir.tmpdir).join('test_queue'), secure: true)
    end

    it 'Recreates the whole TaskQueue from the information stored in the correct order' do
      queue = TaskQueue.new(name: 'test queue')
      tasks = Queue.new
      # We need at least one pending task to let the queue be stored
      task_number = 4
      task_number.times do |i|
        tasks << MockOrderedRecreatableTask.new(number: i).to_task
      end

      allow(queue).to receive(:queue).and_return(tasks)
      TaskQueue.finalizer(name: 'test queue', number_of_workers: 1, tasks: tasks).call

      task_number.times do |i|
        expect(STDOUT).to receive(:puts).with({ one_param: "Hello", other_param: "World", number: i }.to_s)
      end

      recreated_queue = TaskQueue.from_recreated_tasks!(name: 'test queue')
      sleep 0.001 until recreated_queue.task_count.zero?
      expect(recreated_queue.name).to eq('test queue')

      # Cleanup directory
      FileUtils.rm_rf(Pathname.new(Dir.tmpdir).join('test_queue'), secure: true)
    end
  end
end

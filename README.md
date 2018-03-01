[![Twitter: @taquitos](https://img.shields.io/badge/contact-@taquitos-blue.svg?style=flat)](https://twitter.com/taquitos)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/fastlane/TaskQueue/blob/master/LICENSE)

# TaskQueue
A ruby implementation of a simple dispatch queue using procs

Currently, `TaskQueue` only has api for dispatching tasks asynchronously.

## Example

```ruby
# Create a queue with as many workers as you want or 1 for a serial queue 
queue = TaskQueue.new(name: 'my concurrent queue', number_of_workers: 5)
task = Task.new(work_block: proc { 
  # some work to be done
})
queue.add_task_async(task: task)
```

```ruby
# Or don't supply the number of workers and you'll only get 1, making it a serial queue 
queue = TaskQueue.new(name: 'my serial queue')
task = Task.new(work_block: proc { 
  # some work to be done
})
queue.add_task_async(task: task)
```

## Recreatable Tasks

The tasks that are created from the mixin `RecreatableTask` can be recovered in future executions of the `TaskQueue` where their were enqueued originally.

### Example

```ruby
# We define a task that includes RecreatableTask
class HelloToRecreatableTask
  include TaskQueue::RecreatableTask

  # The run! method receives a collection of params and defines the real execution of the task itself.
  def run!(**params)
    puts "Hello #{params}"
  end

  # In case the queue gets deallocated with RecreatableTasks on its queue, the hash returned by this function will be stored. Make sure that all values are JSON encodable.
  def params_to_hash
    { to: "fastlane" }
  end
end

queue = TaskQueue(name: 'test queue')
task = HelloToRecreatableTask.new.to_task
queue.add_task_async(task: task)

```

## Run tests

```
bundle exec rspec
```

[![Twitter: @taquitos](https://img.shields.io/badge/contact-@taquitos-blue.svg?style=flat)](https://twitter.com/taquitos)
[![License](https://img.shields.io/badge/license-MIT-green.svg?style=flat)](https://github.com/fastlane/TaskQueue/blob/master/LICENSE)

# TaskQueue
A ruby implementation of a simple dispatch queue using procs

Currently, `WorkQueue` only has api for dispatching tasks asynchronously.

## Example

```ruby
# Create a queue with as many workers as you want or 1 for a serial queue 
queue = WorkQueue.new(name: 'my concurrent queue', number_of_workers: 5)
task = Task.new(work_block: proc { 
  # some work to be done
})
queue.add_task_async(task: task)
```

```ruby
# Or don't supply the number of workers and you'll only get 1, making it a serial queue 
queue = WorkQueue.new(name: 'my serial queue')
task = Task.new(work_block: proc { 
  # some work to be done
})
queue.add_task_async(task: task)
```

## Run tests

```
bundle exec rspec
```

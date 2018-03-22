Gem::Specification.new do |s|
  s.name        = 'taskqueue'
  s.version     = '0.0.0'
  s.date        = '2018-03-20'
  s.summary     = "Hola!"
  s.description = "A simple hello world gem"
  s.authors     = ["Joshua Liebowitz"]
  s.email       = 'taquitos@gmail.com'
  s.files       = ["lib/task.rb", "lib/task_queue.rb", "lib/queue_worker.rb", "lib/recreatable_task.rb"]
  s.homepage    =
    'http://rubygems.org/gems/hola'
  s.license       = 'MIT'
  s.add_development_dependency 'pry'
  s.add_development_dependency 'pry-byebug'
  s.add_development_dependency 'rspec'
  s.add_development_dependency 'rubocop'
end

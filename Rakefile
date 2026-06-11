# frozen_string_literal: true

require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

require "rubocop/rake_task"

RuboCop::RakeTask.new

Dir[File.join(__dir__, "tasks/**/*.rake")].each { |task_file| import task_file }

task default: %i[spec rubocop]

# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/testtask"

suites = [:vanilla, :activesupport, :activerecord]
namespace :test do
  suites.each do |suite|
    Rake::TestTask.new(suite) do |t|
      t.libs << "test/#{suite}"
      t.libs << "lib"
      t.test_files = FileList["test/#{suite}/**/*_test.rb"]
    end
  end
end

task test: suites.map { |s| "test:#{s}" }

task default: :test

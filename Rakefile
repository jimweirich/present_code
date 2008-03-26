#!/usr/bin/env ruby
# -*- ruby -*-

require "rake/clean"
require "rake/testtask"
require "rakelib/extract"

CLOBBER.include('*.html')

task :default => :extract
task :extract => ["hello.html", 'extract.html']

extract "html/hello.html", "src/hello.rb"
extract "html/extract.html", "rakelib/extract.rb"

Rake::TestTask.new(:test) do |t|
  t.test_files = FileList[
    'test/**/*_test.rb',
  ]
  t.warning = true
  t.verbose = false
end

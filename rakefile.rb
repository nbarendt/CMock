$here = File.expand_path(File.dirname(__FILE__))

require 'rake'
require 'rake/clean'
require 'rake/testtask'
require 'rakefile_helper'

include RakefileConstants
include RakefileHelpers

SYSTEST_TEST_FILES = FileList.new(SYSTEST_TEST_DIR + 'Test*' + C_EXTENSION)

COMPILER_CONFIGS = FileList.new('*.yml')

CLEAN.include(SYSTEST_BUILD_DIR + '*.*')
CLEAN.include(SYSTEST_MOCKS_DIR + '*.*')

task :default => [ :clobber, 'tests:all', :app ]

desc "Build and run application"
task :app do
  COMPILER_CONFIGS.each do |cfg_file|
    build_application(yaml_read(cfg_file), 'Main')
  end
end

namespace :tests do

  desc "Run unit and system tests"
  task :all => [:clean, 'units', 'system', 'app']

  Rake::TestTask.new('units') do |t|
    t.pattern = 'test//unit/*_test.rb'
    t.verbose = true
  end
  
  desc "Run system tests"
  task :system => [:clean] do
    COMPILER_CONFIGS.each do |cfg_file|
     run_systests(yaml_read(cfg_file), SYSTEST_TEST_FILES)
     report_summary
    end
  end
  
end
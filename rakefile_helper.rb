require 'yaml'
require 'lib/cmock'
require 'auto/generate_test_runner'

def Kernel.is_windows?
  processor, platform, *rest = RUBY_PLATFORM.split("-")
  platform == 'mswin32'
end

module RakefileConstants

  C_EXTENSION = '.c'
  OBJ_EXTENSION = '.o'
  
  if (Kernel.is_windows?)
    EXE_EXTENSION = '.exe'
  else
    EXE_EXTENSION = '.out'  
  end
  
  UNITY_DIR = 'vendor/unity/src/'

  SYSTEST_BASE = 'test/system/'
  SYSTEST_SOURCE_DIR = SYSTEST_BASE + 'source/'
  SYSTEST_TEST_DIR   = SYSTEST_BASE + 'test/'
  SYSTEST_MOCKS_DIR  = SYSTEST_BASE + 'mocks/'
  SYSTEST_BUILD_DIR  = SYSTEST_BASE + 'build/'

  SYSTEST_INCLUDE_DIRS = [SYSTEST_SOURCE_DIR, SYSTEST_TEST_DIR, SYSTEST_MOCKS_DIR, UNITY_DIR]

end

module RakefileHelpers

  require 'fileutils'

  def extract_headers(filename)
    includes = []
    lines = File.readlines(filename)
    lines.each do |line|
      m = line.match /#include \"(.*)\"/
      if not m.nil?
        includes << m[1]
      end
    end
    return includes
  end

  def find_source_file(header)
    src_file = ''
    SYSTEST_INCLUDE_DIRS.each do |dir|
      src_file = dir + header.ext(C_EXTENSION)
      if (File.exists?(src_file))
        return src_file
      end
    end
    return ''
  end
  
  def compile(config, file)
    cmd_str = "#{config["path"]}#{config["compiler"]} #{config["compile_flags"]} "
    if !config["path"].nil?
      cmd_str += "-B#{config["path"]} "
    end
    cmd_str += (SYSTEST_INCLUDE_DIRS.map{|dir|"-I#{dir} "}).join +
      "#{file} " +
      "-o #{SYSTEST_BUILD_DIR}#{File.basename(file, C_EXTENSION)}#{OBJ_EXTENSION}"
    execute(cmd_str)
  end
  
  def link(config, exe_name, obj_list)
    cmd_str = "#{config["path"]}#{config["linker"]} "
    if !config["path"].nil?
      cmd_str += "-B#{config["path"]} "
    end
    cmd_str += (obj_list.map{|obj|"#{SYSTEST_BUILD_DIR}#{obj} "}).join +
      "-o #{SYSTEST_BUILD_DIR}#{exe_name}#{EXE_EXTENSION}"
    execute(cmd_str)      
  end
  
  def yaml_read(filename)  
    return YAML.load(File.read(filename))
  end

  def report(message)
    puts message
    $stdout.flush
    $stderr.flush
  end

  def execute(command_string, verbose=true)
    report command_string
    output = `#{command_string}`.chomp
    report(output) if (verbose && !output.nil? && (output.length > 0))
    if $?.exitstatus != 0
      raise "Command failed. (Returned #{$?.exitstatus})"
    end
    return output
  end
  
  def run_systests(config, test_files)
    test_files.each do |test|
      obj_list = []
      test_base = File.basename(test, C_EXTENSION)
      headers = extract_headers(test)
    
      headers.each do |header|
      
        if header =~ /^Mock(.*)\.h/i
          module_name = $1
          report "Generating mock for module #{module_name}..."
          cmock = CMock.new(mocks_path='test/system/mocks')
          cmock.setup_mocks("test/system/source/#{module_name}.h")
        end
      
        compile(config, find_source_file(header))
        obj_list << header.ext(OBJ_EXTENSION)
      end
      
      # Generate and build the test runner
      runner_name = test_base + '_Runner.c'
      runner_path = SYSTEST_BUILD_DIR + runner_name
      test_gen = UnityTestRunnerGenerator.new
      test_gen.run(test, runner_path)
      compile(config, runner_path)
      obj_list << runner_name.ext(OBJ_EXTENSION)
      
      # Build the test file
      compile(config, test)
      obj_list << test_base.ext(OBJ_EXTENSION)
      
      link(config, test_base, obj_list)
      
      execute(SYSTEST_BUILD_DIR + test_base + EXE_EXTENSION)
    end
  end
  
  def build_and_run_application(config, main)
    obj_list = []
    main_path = SYSTEST_SOURCE_DIR + main + '.c'
    executable_path = SYSTEST_BUILD_DIR + main + EXE_EXTENSION
    main_base = File.basename(main_path, C_EXTENSION)
    headers = extract_headers(main_path)
  
    headers.each do |header|
    
      if header =~ /^Mock(.*)\.h/i
        module_name = $1
        report "Generating mock for module #{module_name}..."
        cmock = CMock.new(mocks_path='test/system/mocks')
        cmock.setup_mocks("test/system/source/#{module_name}.h")
      end
    
      compile(config, find_source_file(header))
      obj_list << header.ext(OBJ_EXTENSION)
    end
    
    compile(config, main_path)
    obj_list << main_base.ext(OBJ_EXTENSION)
    
    link(config, main_base, obj_list)
    
    execute(SYSTEST_BUILD_DIR + main_base + EXE_EXTENSION)
  end
  
end


$here = File.dirname __FILE__

class CMockGenerator

  attr_reader :config, :file_writer, :module_name, :mock_name, :utils, :plugins
  
  def initialize(config, module_name, file_writer, utils, plugins=[])
    @file_writer = file_writer
    @module_name = module_name
    @utils       = utils
    @plugins     = plugins
    @config      = config
    @mock_name   = @config.mock_prefix + @module_name
    @ordered     = @config.enforce_strict_ordering
  end

  def create_mock(parsed_stuff)
    create_mock_header_file(parsed_stuff)
    create_mock_source_file(parsed_stuff)
  end
  
  private unless $ThisIsOnlyATest ##############################
  
  def create_mock_header_file(parsed_stuff)
    @file_writer.create_file(@mock_name + ".h") do |file, filename|
      create_mock_header_header(file, filename)
      create_mock_header_service_call_declarations(file)
      parsed_stuff[:functions].each do |function|
        file << @plugins.run(:mock_function_declarations, function)
      end
      create_mock_header_footer(file)
    end
  end

  def create_mock_source_file(parsed_stuff)
    @file_writer.create_file(@mock_name + ".c") do |file, filename|
      create_source_header_section(file, filename)
      create_source_typedefs(file, parsed_stuff[:functions])
      create_instance_structure(file, parsed_stuff[:functions])
      create_extern_declarations(file)
      create_mock_verify_function(file, parsed_stuff[:functions])
      create_mock_init_function(file)
      create_mock_destroy_function(file, parsed_stuff[:functions])
      parsed_stuff[:functions].each do |function|
        create_mock_implementation(file, function)
        file << @plugins.run(:mock_interfaces, function)
      end
    end
  end
  
  def create_mock_header_header(file, filename) 
    define_name   = filename.gsub(/\.h/, "_h").upcase
    orig_filename = filename.gsub(@config.mock_prefix, "")   
    file << "/* AUTOGENERATED FILE. DO NOT EDIT. */\n"
    file << "#ifndef _#{define_name}\n"
    file << "#define _#{define_name}\n\n"
    file << "#include \"#{orig_filename}\"\n\n"
  end
  
  def create_source_typedefs(file, functions)
    file << "\n"
    functions.each do |function|
      function[:typedefs].each {|typedef| file << "#{typedef}\n" }
    end
    file << "\n\n"
  end

  def create_mock_header_service_call_declarations(file) 
    file << "void #{@mock_name}_Init(void);\n"
    file << "void #{@mock_name}_Destroy(void);\n"
    file << "void #{@mock_name}_Verify(void);\n\n"
  end

  def create_mock_header_footer(header)
    header << "\n#endif\n"
  end
  
  def create_source_header_section(file, filename)
    header_file = filename.gsub(".c",".h")
    file << "/* AUTOGENERATED FILE. DO NOT EDIT. */\n"
    file << "#include <string.h>\n"
    file << "#include <stdlib.h>\n"
    file << "#include <setjmp.h>\n"
    file << "#include \"unity.h\"\n"
    file << @plugins.run(:include_files)
    includes = @config.includes
    includes.each {|inc| file << "#include \"#{inc}\"\n"} if (!includes.nil?)
    file << "#include \"#{header_file}\"\n\n"
  end
  
  def create_instance_structure(file, functions)
    file << "static struct #{@mock_name}Instance\n"
    file << "{\n"
    if (functions.size == 0)
      file << "  unsigned char placeHolder;\n"
    end
    file << "  unsigned char allocFailure;\n"
    file << functions.collect{|function| @plugins.run(:instance_structure, function)}.join
    file << "} Mock;\n\n"
  end
  
  def create_extern_declarations(file)
    file << "extern jmp_buf AbortFrame;\n"
    if (@ordered)
      file << "extern int GlobalExpectCount;\n"
      file << "extern int GlobalVerifyOrder;\n"
      file << "extern char* GlobalOrderError;\n"
    end
    file << "\n"
  end
  
  def create_mock_verify_function(file, functions)
    file << "void #{@mock_name}_Verify(void)\n{\n"
    file << "  TEST_ASSERT_EQUAL(0, Mock.allocFailure);\n"
    file << functions.collect {|function| @plugins.run(:mock_verify, function)}.join
    if (@ordered)
      file << "  if (GlobalOrderError)\n"
      file << "  {\n"
      file << "    TEST_FAIL(GlobalOrderError);\n"
      file << "  }\n"
    end
    file << "}\n\n"
  end
  
  def create_mock_init_function(file)
    file << "void #{@mock_name}_Init(void)\n{\n"
    file << "  #{@mock_name}_Destroy();\n"
    file << "}\n\n"
  end
  
  def create_mock_destroy_function(file, functions)
    file << "void #{@mock_name}_Destroy(void)\n{\n"
    file << functions.collect {|function| @plugins.run(:mock_destroy, function) }.join
    file << "  memset(&Mock, 0, sizeof(Mock));\n"
    if (@ordered)
      file << "  GlobalExpectCount = 0;\n"
      file << "  GlobalVerifyOrder = 0;\n"
      file << "  if (GlobalOrderError)\n"
      file << "  {\n"
      file << "    free(GlobalOrderError);\n"
      file << "    GlobalOrderError = NULL;\n"
      file << "  }\n"
    end
    file << "}\n\n"
  end
  
  def create_mock_implementation(file, function)        
    # create return value combo         
    if (function[:modifier].empty?)
      function_mod_and_rettype = function[:return_type] 
    else
      function_mod_and_rettype = function[:modifier] + ' ' + function[:return_type] 
    end
    
    args_string = function[:args_string]
    args_string += (", " + function[:var_arg]) unless (function[:var_arg].nil?)
    
    # Create mock function
    file << "#{function[:attributes]} " if (!function[:attributes].nil? && function[:attributes].length > 0)
    file << "#{function_mod_and_rettype} #{function[:name]}(#{args_string})\n"
    file << "{\n"
    file << @plugins.run(:mock_implementation_prefix, function)
    file << @plugins.run(:mock_implementation, function)
    
    # Return expected value, if necessary
    if (function[:return_type] != "void")
      file << @utils.code_handle_return_value(function, "  ").join
    end
    
    # Close out the function
    file << "}\n\n"
  end
end

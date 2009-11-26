
class CMockGeneratorPluginCexception

  attr_reader :config, :utils

  def initialize(config, utils)
    @config = config
    @utils = utils
    
    raise "'cexception_include' needs to be defined in config" unless @config.respond_to?(:cexception_include)
  end
  
  def include_files
    include = @config.cexception_include
    include = "Exception.h" if (include.nil?)
    return "#include \"#{include}\"\n"
  end
  
  def instance_structure(function)
    INSTANCE_STRUCTURE_SNIPPET % function[:name]
  end
  
  def mock_function_declarations(function)
    if (function[:args_string] == "void")
	    return "void #{function[:name]}_ExpectAndThrow(EXCEPTION_T toThrow);\n"
    else        
	    return "void #{function[:name]}_ExpectAndThrow(#{function[:args_string]}, EXCEPTION_T toThrow);\n"
    end
  end
  
  def mock_implementation(function)
    MOCK_IMPLEMENTATION_SNIPPET % function[:name]
  end
  
  def mock_interfaces(function)
    arg_insert = (function[:args_string] == "void") ? "" : "#{function[:args_string]}, "
    [ "void #{function[:name]}_ExpectAndThrow(#{arg_insert}EXCEPTION_T toThrow)\n{\n",
      @utils.code_add_base_expectation(function[:name]),
      @utils.code_insert_item_into_expect_array('int', "Mock.#{function[:name]}_ThrowOnCallCount", "Mock.#{function[:name]}_CallsExpected"),
      @utils.code_insert_item_into_expect_array('EXCEPTION_T', "Mock.#{function[:name]}_ThrowValue", "toThrow"),
      (MOCK_INTERFACE_THROW_HANDLING_SNIPPET % function[:name]),
      (function[:args_string] != "void") ? "  ExpectParameters_#{function[:name]}(#{@utils.create_call_list(function)});\n" : nil,
      "}\n\n" ].join
  end
  
  def mock_destroy(function)
    MOCK_DESTROY_SNIPPET % function[:name]
  end
  
  private ############
  
  INSTANCE_STRUCTURE_SNIPPET = %q[
  int *%1$s_ThrowOnCallCount;
  int *%1$s_ThrowOnCallCount_Head;
  int *%1$s_ThrowOnCallCount_Tail;
  EXCEPTION_T *%1$s_ThrowValue;
  EXCEPTION_T *%1$s_ThrowValue_Head;
  EXCEPTION_T *%1$s_ThrowValue_Tail;
]

  MOCK_IMPLEMENTATION_SNIPPET = %q[
  if ((Mock.%1$s_ThrowOnCallCount != Mock.%1$s_ThrowOnCallCount_Tail) &&
     (Mock.%1$s_ThrowValue != Mock.%1$s_ThrowValue_Tail))
  {
    if (*Mock.%1$s_ThrowOnCallCount && 
      (Mock.%1$s_CallCount == *Mock.%1$s_ThrowOnCallCount))
    {
      EXCEPTION_T toThrow = *Mock.%1$s_ThrowValue;
      Mock.%1$s_ThrowOnCallCount++;
      Mock.%1$s_ThrowValue++;
      Throw(toThrow);
    }
  }
]

  MOCK_DESTROY_SNIPPET = %q[
  if(Mock.%1$s_ThrowOnCallCount_Head)
  {
    free(Mock.%1$s_ThrowOnCallCount_Head);
  }
  Mock.%1$s_ThrowOnCallCount=NULL;
  Mock.%1$s_ThrowOnCallCount_Head=NULL;
  Mock.%1$s_ThrowOnCallCount_Tail=NULL;
  if(Mock.%1$s_ThrowValue_Head)
  {
    free(Mock.%1$s_ThrowValue_Head);
  }
  Mock.%1$s_ThrowValue=NULL;
  Mock.%1$s_ThrowValue_Head=NULL;
  Mock.%1$s_ThrowValue_Tail=NULL;
]

  MOCK_INTERFACE_THROW_HANDLING_SNIPPET = %q[
  Mock.%1$s_ThrowValue = Mock.%1$s_ThrowValue_Head;
  Mock.%1$s_ThrowOnCallCount = Mock.%1$s_ThrowOnCallCount_Head;
  while ((*Mock.%1$s_ThrowOnCallCount <= Mock.%1$s_CallCount) && (Mock.%1$s_ThrowOnCallCount < Mock.%1$s_ThrowOnCallCount_Tail))
  {
    Mock.%1$s_ThrowValue++;
    Mock.%1$s_ThrowOnCallCount++;
  }
]
end

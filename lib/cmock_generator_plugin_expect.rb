
class CMockGeneratorPluginExpect

  attr_accessor :config, :utils, :tab, :unity_helper, :ordered

  def initialize(config, utils)
    @config       = config
	  @tab          = @config.tab
    @ptr_handling = @config.when_ptr_star
    @ordered      = @config.enforce_strict_ordering
    @utils        = utils
    @unity_helper = @utils.helpers[:unity_helper]
  end
  
  def instance_structure(function)
    call_count_type = @config.expect_call_count_type
    lines = [ "#{@tab}#{call_count_type} #{function[:name]}_CallCount;\n",
              "#{@tab}#{call_count_type} #{function[:name]}_CallsExpected;\n" ]
      
    if (function[:rettype] != "void")
      lines << [ "#{@tab}#{function[:rettype]} *#{function[:name]}_Return;\n",
                 "#{@tab}#{function[:rettype]} *#{function[:name]}_Return_Head;\n",
                 "#{@tab}#{function[:rettype]} *#{function[:name]}_Return_Tail;\n" ]
    end

    if (@ordered)
      lines << [ "#{@tab}#{function[:rettype]} *#{function[:name]}_CallOrder;\n",
                 "#{@tab}#{function[:rettype]} *#{function[:name]}_CallOrder_Head;\n",
                 "#{@tab}#{function[:rettype]} *#{function[:name]}_CallOrder_Tail;\n" ]
    end
    
    function[:args].each do |arg|
      type = arg[:type].sub(/const/, '').strip
      lines << [ "#{@tab}#{type} *#{function[:name]}_Expected_#{arg[:name]};\n",
                 "#{@tab}#{type} *#{function[:name]}_Expected_#{arg[:name]}_Head;\n",
                 "#{@tab}#{type} *#{function[:name]}_Expected_#{arg[:name]}_Tail;\n" ]
    end
    lines.flatten
  end
  
  def mock_function_declarations(function)
    if (function[:args_string] == "void")
      if (function[:rettype] == 'void')
        return "void #{function[:name]}_Expect(void);\n"
      else
        return "void #{function[:name]}_ExpectAndReturn(#{function[:rettype]} toReturn);\n"
      end
    else        
      if (function[:rettype] == 'void')
        return "void #{function[:name]}_Expect(#{function[:args_string]});\n"
      else
        return "void #{function[:name]}_ExpectAndReturn(#{function[:args_string]}, #{function[:rettype]} toReturn);\n"
      end
    end
  end
  
  def mock_implementation(function)
    lines = [ "#{@tab}Mock.#{function[:name]}_CallCount++;\n",
              "#{@tab}if (Mock.#{function[:name]}_CallCount > Mock.#{function[:name]}_CallsExpected)\n",
              "#{@tab}{\n",
              "#{@tab}#{@tab}TEST_FAIL(\"#{function[:name]} Called More Times Than Expected\");\n",
              "#{@tab}}\n" ]
    
    if (@ordered)
      lines << [ "#{@tab}{\n",
                 "#{@tab}#{@tab}int* p_expected = Mock.#{function[:name]}_CallOrder;\n",
                 "#{@tab}#{@tab}++GlobalVerifyOrder;\n",
                 "#{@tab}#{@tab}if (Mock.#{function[:name]}_CallOrder != Mock.#{function[:name]}_CallOrder_Tail)\n",
                 "#{@tab}#{@tab}#{@tab}Mock.#{function[:name]}_CallOrder++;\n",
                 @utils.expect_helper('int', '*p_expected', 'GlobalVerifyOrder', "\"Function '#{function[:name]}' Called Out Of Order.\"","#{@tab}#{@tab}"),
                 "#{@tab}}\n" ]
    end
    
    function[:args].each do |arg|
      arg_return_type = arg[:type].sub(/const/, '').strip
      lines << @utils.code_verify_an_arg_expectation(function, arg_return_type, arg[:name])
    end
    lines.flatten
  end
  
  def mock_interfaces(function)
    lines = []
    
    # Parameter Helper Function
    if (function[:args_string] != "void")
      lines << "void ExpectParameters_#{function[:name]}(#{function[:args_string]})\n"
      lines << "{\n"
      function[:args].each do |arg|
        type = arg[:type].sub(/const/, '').strip
        lines << @utils.code_add_an_arg_expectation(function, type, arg[:name])
      end
      lines << "}\n\n"
    end
    
    #Main Mock Interface
    if (function[:rettype] == "void")
      lines << "void #{function[:name]}_Expect(#{function[:args_string]})\n"
    else
      if (function[:args_string] == "void")
        lines << "void #{function[:name]}_ExpectAndReturn(#{function[:rettype]} toReturn)\n"
      else
        lines << "void #{function[:name]}_ExpectAndReturn(#{function[:args_string]}, #{function[:rettype]} toReturn)\n"
      end
    end
    lines << "{\n"
    lines << @utils.code_add_base_expectation(function[:name])
    
    if (function[:args_string] != "void")
      lines << "#{@tab}ExpectParameters_#{function[:name]}(#{@utils.create_call_list(function)});\n"
    end
    
    if (function[:rettype] != "void")
      lines << @utils.code_insert_item_into_expect_array(function[:rettype], "Mock.#{function[:name]}_Return_Head", "toReturn")
      lines << "#{@tab}Mock.#{function[:name]}_Return = Mock.#{function[:name]}_Return_Head;\n"
      lines << "#{@tab}Mock.#{function[:name]}_Return += Mock.#{function[:name]}_CallCount;\n"
    end
    lines << "}\n\n"
  end
  
  def mock_verify(function)
    return "#{@tab}TEST_ASSERT_EQUAL_MESSAGE(Mock.#{function[:name]}_CallsExpected, Mock.#{function[:name]}_CallCount, \"Function '#{function[:name]}' called unexpected number of times.\");\n"
  end
  
  def mock_destroy(function)
    lines = []
    if (function[:rettype] != "void")
      lines << [ "#{@tab}if (Mock.#{function[:name]}_Return_Head)\n",
                 "#{@tab}{\n",
                 "#{@tab}#{@tab}free(Mock.#{function[:name]}_Return_Head);\n",
                 "#{@tab}#{@tab}Mock.#{function[:name]}_Return_Head=NULL;\n",
                 "#{@tab}#{@tab}Mock.#{function[:name]}_Return_Tail=NULL;\n",
                 "#{@tab}}\n" ]
    end
    function[:args].each do |arg|
      lines << [ "#{@tab}if (Mock.#{function[:name]}_Expected_#{arg[:name]}_Head)\n",
                 "#{@tab}{\n",
                 "#{@tab}#{@tab}free(Mock.#{function[:name]}_Expected_#{arg[:name]}_Head);\n",
                 "#{@tab}#{@tab}Mock.#{function[:name]}_Expected_#{arg[:name]}_Head=NULL;\n",
                 "#{@tab}#{@tab}Mock.#{function[:name]}_Expected_#{arg[:name]}_Tail=NULL;\n",
                 "#{@tab}}\n" ]
    end
    lines.flatten
  end
end

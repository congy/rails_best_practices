require 'sorcerer'
require 'pp'
module RailsBestPractices
  module Reviews
    # Find out unused methods in models.
    #
    # Implemenation:
    #
    # Review process:
    #   remember all method calls,
    #   at end, check if all defined methods are called,
    #   if not, non called methods are unused.
    class PrintCustomValidationReview < Review
      interesting_nodes :def, :defs, :command, :module, :class, :method_add_arg, :method_add_block
      interesting_files MODEL_FILES
      url 'https://rails-bestpractices.com/posts/2010/10/03/use-query-attribute/'

			def initialize(options = {})
				puts "INITIALIZE"	
        super(options)
				@current_class_name = nil
			end
      add_callback :start_module do |node|
        @current_class_name = node.module_name.to_s
      end
      add_callback :start_class do |node|
        @current_class_name = node.class_name.to_s
			end

			add_callback :start_def, :start_defs, :start_command do |node|
        arguments = node.arguments.all
        case node.message.to_s
          when 'validate'
            arguments.each do |arg1|
              puts "\n#{@node.file} : #{to_source(node)}"
							begin
								m = get_method("#{arg1}")
								if m
									puts to_source(m.node)
								end
								puts "==========\n"
              rescue => error
                puts "Error = #{error}"
							end
					  end
				end
			end

			def get_method(meth_name)
        method = model_methods.get_method(@current_class_name, meth_name)
				#puts "Meths = #{model_methods.get_methods(@current_class_name).map{|x| "#{x.method_name}(#{x.method_name==meth_name})"}.join(', ')}"
				#puts "class = #{@current_class_name}, func = #{meth_name}, meth = #{method}"
        method
			end

      def to_source(node)
        return Sorcerer.source(node, multiline:false, indent:2)
      end
		end
	end
end


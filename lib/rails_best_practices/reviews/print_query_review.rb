require 'sorcerer'
require 'pp'

module RailsBestPractices
  module Reviews
    class PrintQueryReview < Review
      interesting_nodes :def, :command, :module, :class, :method_add_arg, :method_add_block
      interesting_files CONTROLLER_FILES, MODEL_FILES, LIB_FILES, HELPER_FILES, VIEW_FILES
      url 'https://rails-bestpractices.com/posts/2010/10/03/use-query-attribute/'


      MULTI_QUERY_METHODS = %w[where pluck distinct eager_load from group having includes joins left_outer_joins limit offset order preload readonly reorder select reselect select_all reverse_order unscope find_each rewhere].freeze
      SINGLE_QUERY_METHODS = %w[find find! take take! first first! last last! find_by find_by!].freeze
      add_callback :start_module do |node|
        @current_class_name = node.module_name.to_s
        @local_variable ||= {}
      end

      add_callback :start_class do |node|
        @current_class_name = node.class_name.to_s
        @local_variable ||= {}
      end


      add_callback :start_def, :start_command do |node|
        if node.sexp_type == :def
          node.recursive_children do |child|
            if is_method_call?(child)
              r = process_methodcall_node?(child, true)
            elsif child.sexp_type == :assign && is_method_call?(child[2])
              r = process_methodcall_node?(child[2], true)
              if r != nil
                @local_variable.store(child[1].to_s, to_source(child))
              end
            end
          end
        elsif node.sexp_type == :command
          case node.message.to_s
            when 'named_scope', 'scope'
              node.recursive_children do |child|
                if is_method_call?(child)
                  r = process_methodcall_node?(child, true)
                end
              end
            end
        end
      end

      def is_method_call?(node)
        return [:method_add_arg, :method_add_block, :call].include?node.sexp_type
      end
      
      def process_methodcall_node?(node, printout)
        @processed_node ||= []
        if @processed_node.include?(node)
          return nil
        end
        node.recursive_children do |child|
          if [:method_add_arg, :method_add_block, :call].include?child.sexp_type
            @processed_node << child
          end
        end
        @processed_node << node
        node_list ||= []
        call_node = nil
        if node.sexp_type == :call
          call_node = node
        else
          node.children.each do |child| 
            if child.sexp_type == :call
              call_node = child
            end
          end 
        end
        if call_node == nil
          return nil
        end
        node_list << call_node
        call_node.recursive_children do |child|
          if [:call, :var_ref].include?(child.sexp_type)
            node_list << child
          end
        end
      
        variable_node = variable(call_node)
        if !is_model?(variable_node)
          return nil
        end

        class_name = get_class_name(variable_node)

        output = ["\n===="]
        output << "Query: #{@node.file}"
        if @local_variable.include?(variable_node.to_s)
          output << (@local_variable[variable_node.to_s])
        end
        output << (to_source(node))
        
        @processed_node = @processed_node + node_list
        #node_list << temp_node.receiver
        meth_list ||= []
        contain_query = false
        classes ||= [class_name]
        node_list.reverse.each do |cnode|
          if cnode.sexp_type == :call
            fcall_name = cnode.message.to_s
            if model_association?(class_name, fcall_name)
              class_name = model_association?(class_name, fcall_name)['class_name']
              classes << class_name
            elsif model_method?(class_name, fcall_name)
              meth = model_method?(class_name, fcall_name)
              #puts "Find meth #{to_source(meth.node)}"
              meth_list << meth
            #elsif MULTI_QUERY_METHODS.include?(fcall_name)
            #elsif SINGLE_QUERY_METHODS.include?(fcall_name)
            #else
            #  break
            end
          #else  
          end
        end
        if printout && meth_list.length > 0
          meth_list.each do |meth|
            output << " * * meth #{meth.file}"
            output << (to_source(meth.node))
          end
        end
        if printout
          o = output.join(" ").to_s
          validations = find_corresponding_validation(classes, o)
          validations.each do |validation|
            output << " ## involved validation #{validation[0]}: #{validation[1]}"
          end
          o = output.join("\n")
          if (MULTI_QUERY_METHODS+SINGLE_QUERY_METHODS).map{|x| o.include?(x)}.any?
            puts o
            puts "===="
          end
        end
        return to_source(node)
      end

      def is_self?(variable_node)
        if variable_node.sexp_type == :var_ref && variable_node.to_s == "self"
          return models.include?(@current_class_name)
        end
        return false
      end

      def is_model?(variable_node)
        if is_self?(variable_node)
          return true
        elsif variable_node.const?
          class_name = variable_node.to_s
        else
          class_name = variable_node.to_s.sub(/^@/, '').classify
        end
        models.include?(class_name)
      end

      def get_class_name(variable_node)
        if is_self?(variable_node)
          return @current_class_name
        elsif variable_node.const?
          return variable_node.to_s
        else
          return variable_node.to_s.sub(/^@/, '').classify
        end
      end

      def model_association?(class_name, message)
        assoc_type = model_associations.get_association(class_name, message)
        assoc_type
      end
      def model_method?(class_name, message)
        method = model_methods.get_method(class_name, message)
        method
      end

      def to_source(node)
        return Sorcerer.source(node, multiline:true, indent:2)
      end

      def find_corresponding_validation(classes, function_source)
        involved_validations ||= []
        # a simple match to see if every field involved in the validation is 
        classes.each do |class_name|
          model_validations.get_validations(class_name).each do |pair|
            attribs = pair[0]
            validation_node = pair[1]
            # real_attribs ||= []
            # attribs.each do |attrib|
            #   if model_attributes.is_attribute?(class_name, attrib)
            #     real_attribs << attrib
            #   end
            # end
          
            contain_all_fields = true
            # real_attribs.each do |attrib|
            attribs.each do |attrib|
              if !function_source.include?(attrib)
                contain_all_fields = false
                break
              end
            end
            if contain_all_fields==true
              involved_validations.push [class_name, to_source(validation_node)]
            end
          end
        end  
        involved_validations  
      end
    end
  end
end
require 'sorcerer'
require 'pp'

module RailsBestPractices
  module Reviews
    class PrintQueryReview < Review
      interesting_nodes :def, :defs, :command, :module, :class, :method_add_arg, :method_add_block
      interesting_files CONTROLLER_FILES, MODEL_FILES #LIB_FILES, HELPER_FILES, VIEW_FILES
      url 'https://rails-bestpractices.com/posts/2010/10/03/use-query-attribute/'

      MULTI_QUERY_METHODS = %w[where pluck distinct eager_load from group having includes joins left_outer_joins limit offset order preload readonly reorder select reselect select_all reverse_order unscope find_each rewhere].freeze
      SINGLE_QUERY_METHODS = %w[find find! take take! first first! last last! find_by find_by!].freeze

      def initialize(options = {})
        super(options)
        @collected_queries = []
        #@output_filename = options['output_filename']
      end

      add_callback :start_module do |node|
        @current_class_name = node.module_name.to_s
        puts "start_module"
      end

      add_callback :start_class do |node|
        @current_class_name = node.class_name.to_s
        puts "start_class"
      end

      add_callback :after_check do
        File.open(@output_filename, 'wb') {|f| f.write(Marshal.dump(@collected_queries))}
        puts "Output written to #{@output_filename}"
      end


      add_callback :start_def, :start_defs do |node|
          if node.sexp_type == :def or node.sexp_type == :defs
              node.recursive_children do |child|
                begin
                  if is_method_call?(child)
                    process_method_call_node(child)
                  elsif child.sexp_type == :assign && child[2] && is_method_call?(child[2])
                    process_method_call_node(child[2])
                  end
                rescue
                end
              end
          end
      end

      def is_method_call?(node)
        return [:method_add_arg, :call].include?node.sexp_type
      end
      
      def process_method_call_node(node)
        @processed_node ||= []
        return if @processed_node.include?(node)
        @processed_node << node

        call_node = nil
        if node.sexp_type == :call
          call_node = node
        end

        node.recursive_children do |child|
            @processed_node << child
            call_node = child if call_node == nil and child.sexp_type == :call
        end

        variable_node = variable(call_node)

        return if !is_model?(variable_node)

        source = to_source(node).chomp

        if (MULTI_QUERY_METHODS+SINGLE_QUERY_METHODS).map{|x| source.include?(x)}.any?
          @collected_queries << {:class => @current_class_name, :stmt => source}
        end
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

      def to_source(node)
        return Sorcerer.source(node, multiline:false, indent:2)
      end
    end
  end
end
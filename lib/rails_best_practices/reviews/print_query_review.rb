require 'sorcerer'
require 'pp'

module RailsBestPractices
  module Reviews
    class PrintQueryReview < Review
      interesting_nodes :def, :defs, :command, :module, :class, :method_add_arg, :method_add_block
      interesting_files CONTROLLER_FILES, MODEL_FILES, LIB_FILES, HELPER_FILES #VIEW_FILES
      url 'https://rails-bestpractices.com/posts/2010/10/03/use-query-attribute/'

      MULTI_QUERY_METHODS = %w[where pluck distinct eager_load from group having includes joins left_outer_joins limit offset order preload readonly reorder select reselect select_all reverse_order unscope find_each rewhere].freeze
      SINGLE_QUERY_METHODS = %w[find find! take take! first first! last last! find_by find_by!].freeze

      def initialize(options = {})
        super(options)
        @collected_queries = []
        @scopes = {}
        @output_filename_query = options['output_filename_query']
        @output_filename_scope = options['output_filename_scope']

        @combined_class_name = ""
      end

      add_callback :end_module, :end_class do |node|
        @combined_class_name = ""
      end

      add_callback :start_module do |node|
        @current_class_name = node.module_name.to_s
        @combined_class_name += node.module_name.to_s
      end

      add_callback :start_class do |node|
        @current_class_name = node.class_name.to_s
        @combined_class_name += node.class_name.to_s
      end
      
      add_callback :after_check do
        File.open(@output_filename_query, 'wb') {|f| f.write(Marshal.dump(@collected_queries))}
        puts "Query output written to #{@output_filename_query}"
        File.open(@output_filename_scope, 'wb') {|f| f.write(Marshal.dump(@scopes))}
        puts "Scope output written to #{@output_filename_scope}"
      end


      add_callback :start_def, :start_defs, :start_command do |node|
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
          elsif node.sexp_type == :command and (node.message.to_s == "scope" or node.message.to_s == "named_scope")
            process_scope(node)
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
          @collected_queries << {:class => @combined_class_name, :stmt => source}
        end
      end

      def process_scope(node)
        begin
          scope_name = node.arguments.all[0].to_s

          scope_def = nil
          node.arguments.all[1].recursive_children do |child|
            begin
              if child.sexp_type == :stmts_add
                scope_def = child
                break
              end
            rescue
            end
          end

          scope_def = to_source(scope_def).strip

          if (MULTI_QUERY_METHODS+SINGLE_QUERY_METHODS).map{|x| scope_def.include?(x)}.any?
            key = @current_class_name + "-" + scope_name
            @scopes[key] = scope_def
          end
        rescue
        end
      end

      def is_self?(variable_node)
        return true if variable_node.base_class.is_a?(CodeAnalyzer::Nil) # No calling variable so implicitly self

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

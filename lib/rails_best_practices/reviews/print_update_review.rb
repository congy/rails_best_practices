require "sorcerer"
require "pp"

module RailsBestPractices
  module Reviews
    class PrintUpdateReview < Review
      interesting_nodes :def, :defs, :command, :module, :class, :method_add_arg, :method_add_block
      interesting_files CONTROLLER_FILES, MODEL_FILES, LIB_FILES, HELPER_FILES #VIEW_FILES
      url "https://rails-bestpractices.com/posts/2010/10/03/use-query-attribute/"

      def initialize(options = {})
        puts "INITIALIZE"
        super(options)
        @current_class_name = nil
        @all_assigns = Hash.new
        @assigns = Hash.new # key: variable; value: model_name
      end

      add_callback :start_module do |node|
        @current_class_name = node.module_name.to_s
        @all_assigns = Hash.new
      end
      add_callback :start_class do |node|
        @current_class_name = node.class_name.to_s
      end

      #add_callback :start_call, :start_command_call, :start_method_add_arg do |node|
      #  unless @already_checked == node
      #    message = node.message.to_s
      #    if %w[save update_attributes].include? message

      # add_callback :after_check do
      #   @assigns.each do |model, assign_stmts|
      #     puts "Assign to #{model}:"
      #     fields = []
      #     assign_stmts.each do |meth_name, assign|
      #       next if assign.length == 0
      #       puts "\tmeth #{assign[0][:file]} : #{meth_name}"
      #       assign.each do |a|
      #         #   puts "\t\t#{a[:source].gsub(/[\r\n]+/, "")} || #{a[:fields]}"
      #         # puts "\t\t#{a[:source].gsub(/[\r\n]+/, "")}"
      #         fields = fields + a[:fields]
      #       end
      #     end
      #     model_attribs = model_attributes.get_attribute_for(model)
      #     left_fields = model_attribs.select { |x| !fields.include?(x.to_s) }
      #     puts "\t-- left attribs = #{left_fields}"
      #     puts ""
      #   end
      # end

      add_callback :start_def, :start_defs, :start_command do |node|
        current_method = node.method_name.to_s
        if node.sexp_type == :def or node.sexp_type == :defs
          node.recursive_children do |child|
            begin
              if child.sexp_type == :assign
                #puts "assign #{child[1].to_s} #{child[2].message.to_s} || #{@node.file}"
                # build/create/new
                # assign to field
                lft = child[1].to_s
                model_name = nil
                fields = []
                if lft.include?(".") && is_model?(lft.split(".")[0])
                  model_name = get_model(lft.split(".")[0])
                end
                if lft.include?(".") && lft.split(".")[0] == "self" && models.include?(@current_class_name)
                  model_name = @current_class_name
                end
                if lft.include?(".") && @all_assigns.has_key?(lft.split(".")[0])
                  model_name = @all_assigns[lft.split(".")[0]]
                end
                if !model_name.nil?
                  #puts "assign #{child[1].to_s} || #{current_method} #{@node.file}"
                  fields = find_all_fields_involved(child, model_name)
                  #puts "\tfields = #{fields}"
                  add_to_assign(current_method, child, model_name, child[1], fields)
                end
                if !child[2].nil? && ["new", "build", "create"].include?(child[2].message.to_s)
                  #puts "new: #{lft} || #{to_source(child)} #{@node.file} "
                  if model_name.nil?
                    model_name = find_const_model_name(child[2])
                  end
                  if !model_name.nil?
                    @all_assigns[lft] = model_name
                  end
                  if child[2].message.to_s == "new" and !model_name.nil?
                    # extract constraints:
                    # @time_entry = TimeEntry.new(:issue => @issue, :project => @issue.project)
                    if child[2].sexp_type == :method_add_arg && child[2].arguments.all.first.sexp_type == :bare_assoc_hash
                      child[2].arguments.all.each { |arg|
                        var_refs = arg.hash_values.select { |e| e.sexp_type == :var_ref }
                        calls = arg.hash_values.select { |e| e.sexp_type == :call }
                        constraints = []
                        calls.each { |call|
                          idx = arg.hash_values.find_index { |v| v.to_s == call[1].to_s }
                          if idx
                            puts "Source:"
                            puts "\t" + to_source(child)
                            puts "Constraint:"
                            assign_field_idx = arg.hash_values.find_index(call)
                            puts "\t" + model_name.to_s + "." + arg.hash_keys[idx].to_s + "." + call[3].to_s \
                                   + " = " + model_name.to_s + "." + arg.hash_keys[assign_field_idx].to_s
                          end
                        }
                      }
                    end

                    fields = find_all_fields_involved(child, model_name)
                    #puts "\tfields = #{fields}"
                    add_to_assign(current_method, child, model_name, child[1], fields)
                  end
                elsif !child[2].nil? && ["save", "save!"].include?(child[2].message.to_s)
                  add_to_assign(current_method, child, model_name, child[1], [])
                end
              end
            rescue => error
              puts "ERROR: #{error}"
            end
          end
        end
      end

      def add_to_assign(meth_name, node, model, variable, fields)
        if !@assigns.has_key?(model)
          @assigns[model] ||= Hash.new # key: meth_name, value: {}
        end
        if !@assigns[model].has_key?(meth_name)
          @assigns[model][meth_name] ||= []
        end
        @assigns[model][meth_name] << { :source => to_source(node),
                                        :fields => fields,
                                        :variable => variable,
                                        :file => @node.file }
      end

      def is_method_call?(node)
        return [:method_add_arg, :call].include? node.sexp_type
      end

      def find_all_fields_involved(node, model_class, depth = 1)
        if depth > 10
          return []
        end
        model_attribs = model_attributes.get_attribute_for(model_class)
        fields = []
        node.recursive_children do |child|
          #puts "\t#{child.to_s} || #{child.sexp_type}"
          if [:call, :var_ref, :vcall].include?(child.sexp_type)
            meth_node = nil
            if controller_methods.has_method?(@current_class_name, child.to_s)
              meth_node = controller_methods.get_method(@current_class_name, child.to_s).node
            end
            if helper_methods.has_method?(@current_class_name, child.to_s)
              meth_node = helper_methods.get_method(@current_class_name, child.to_s).node
            end
            if lib_methods.has_method?(@current_class_name, child.to_s)
              meth_node = helper_methods.get_method(@current_class_name, child.to_s).node
            end
            if !meth_node.nil?
              fields = fields + find_all_fields_involved(meth_node, model_class, depth + 1)
            end
          end
          if !model_attribs[child.to_s].nil?
            fields << child.to_s
          end
        end
        return fields.uniq
      end

      def find_const_model_name(node)
        node.recursive_children do |child|
          if child.const?
            class_name = child.to_s
            if models.include?(class_name)
              return class_name
            end
          end
        end
        return nil
      end

      def is_model?(obj_name)
        class_name = obj_name.sub(/^@/, "").classify
        models.include?(class_name)
      end

      def get_model(obj_name)
        return obj_name.sub(/^@/, "").classify
      end

      def to_source(node)
        return Sorcerer.source(node, multiline: false, indent: 2)
      end

      def get_file_and_line_number(node)
        line = node.right_value.line_number
        file = @node.file
        return "#{file} : #{line}"
      end
    end
  end
end

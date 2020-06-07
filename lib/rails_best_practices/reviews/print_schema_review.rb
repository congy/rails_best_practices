require 'sorcerer'
require 'pp'
require 'json'
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
    class PrintSchemaReview < Review
      interesting_nodes :def, :defs, :command, :module, :class, :method_add_arg, :method_add_block
      interesting_files MODEL_FILES
      url 'https://rails-bestpractices.com/posts/2010/10/03/use-query-attribute/'

			def initialize(options = {})
				puts "INITIALIZE"	
        super(options)
				@current_class_name = nil
        @output_file = options['output_file']
				@model_attrs ||= {}
			end
      add_callback :start_module do |node|
        @current_class_name = node.module_name.to_s
      end
      add_callback :start_class do |node|
        @current_class_name = node.class_name.to_s
			end

			add_callback :after_check do
				collect_schema
				File.open(@output_file, 'wb'){|f| f.write(JSON.pretty_generate(@model_attrs))}
			end

			def collect_schema 
				model_hash = models.map{|model| [model.class_name, model]}.to_h
				nochange = false
				model_attribs = models.map{|model| [model.class_name, model_attributes.get_attribute_for(model.class_name)]}.to_h
				model_assocs = models.map{|model| [model.class_name, model_associations.get_association_for(model.class_name)]}.to_h
				while !nochange
					nochange = true
					models.each do |model|
						if !model_hash[model.extend_class_name].nil?
							if model_attribs[model.extend_class_name]["type"].nil?
								model_attribs[model.extend_class_name]["type"] = "string"
							end
							model_attribs[model.extend_class_name].each do |field,type|
								if model_attribs[model.class_name][field].nil?
									nochanged = false
									model_attribs[model.class_name][field] = type
								end
							end
							model_assocs[model.extend_class_name].each do |name,assoc|
								if model_assocs[model.class_name][name].nil?
									nochange = false
									model_assocs[model.class_name][name] = assoc
								end
							end
						end
					end
				end
				models.each do |model|
					x = model_attribs[model.class_name]
					y = model_assocs[model.class_name]
					@model_attrs[model] = {:fields => x, :associations => y.map{ |name,assoc| {:class_name=>assoc['class_name'].to_s, :rel=>assoc['meta'], :field=>name} }, :extend_class_name => model.extend_class_name, :table_name => [ActiveSupport::Inflector.tableize(model.class_name), ActiveSupport::Inflector.singularize(ActiveSupport::Inflector.tableize(model.class_name))] }
					#puts "Model #{model.class_name}, extends #{model.extend_class_name}"
					#puts "\tfields = #{x.inspect}"
					#puts "\tassocs = #{y.map{|n,a| n+'->'+a['class_name']}.join(', ')}"
				end
			end
		end
	end
end


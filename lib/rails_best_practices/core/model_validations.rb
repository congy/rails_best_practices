module RailsBestPractices
  module Core
    # Model validations container.
    class ModelValidations
      def initialize
        @validations = {}
      end
      def add_validation(model_name, node)
        @validations[model_name] ||= []
        #puts "Validation node = #{node.inspect}"
        attribs ||= []
        node.grep_nodes(sexp_type: :symbol) do |symb_node|
          attribs << symb_node[1].to_s
        end
        #puts "Attibs = #{attribs.inspect}"
        if attribs.length > 0
          @validations[model_name].push [attribs, node]
        end
      end
      def get_validations(model_name)
        @validations[model_name] ||= []
        return @validations[model_name]
      end
    end
  end
end
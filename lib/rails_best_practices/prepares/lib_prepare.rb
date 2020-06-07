# frozen_string_literal: true

module RailsBestPractices
  module Prepares
    # Remember lib methods.
    class LibPrepare < Core::Check
      include Core::Check::Moduleable
      include Core::Check::Accessable

      interesting_nodes :def, :command
      interesting_files LIB_FILES, CONTROLLER_FILES

      def initialize
        @libs = Prepares.libs
        @methods = Prepares.lib_methods
      end

      # check module node to remember the module name.
      add_callback :start_module do |_node|
        @libs << Core::Mod.new(current_module_name, [])
      end

      # check def node to remember all methods.
      #
      # the remembered methods (@methods) are like
      #     {
      #       "Postslib" => {
      #         "create_time" => {"file" => "app/libs/posts_lib.rb", "line_number" => 10, "unused" => false},
      #         "update_time" => {"file" => "app/libs/posts_lib.rb", "line_number" => 10, "unused" => false}
      #       }
      #     }
      add_callback :start_def do |node|
        if node.file =~ LIB_FILES
          method_name = node.method_name.to_s
          @methods.add_method(current_module_name, method_name, { 'file' => node.file, 'line_number' => node.line_number }, current_access_control, node)
        end
      end
    end
  end
end

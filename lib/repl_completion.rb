# frozen_string_literal: true

require_relative 'repl_completion/version'
require_relative 'repl_completion/type_analyzer'
require_relative 'repl_completion/result'

module ReplCompletion
  class << self
    attr_reader :last_analyze_error

    def rbs_load_error
      Types.rbs_load_error
    end

    def rbs_load_started?
      Types.rbs_load_started?
    end

    def rbs_loaded?
      !!Types.rbs_builder
    end

    def load_rbs
      Types.load_rbs_builder unless rbs_loaded?
    end

    def preload_rbs
      Types.preload_rbs_builder
    end

    def analyze(code, binding)
      preload_rbs
      begin
        verbose, $VERBOSE = $VERBOSE, nil
        result = analyze_code(code, binding)
      rescue Exception => e
        handle_error(e)
      ensure
        $VERBOSE = verbose
      end
      Result.new(result, binding) if result
    end

    def handle_error(e)
      @last_analyze_error = e
    end

    def info
      require 'rbs'
      prism_info = "Prism: #{Prism::VERSION}"
      rbs_info = "RBS: #{RBS::VERSION}"
      if rbs_load_error
        rbs_info << " #{rbs_load_error.inspect}"
      elsif !rbs_load_started?
        rbs_info << ' signatures not loaded'
      elsif !rbs_loaded?
        rbs_info << ' signatures loading'
      end
      "ReplCompletion: #{VERSION}, #{prism_info}, #{rbs_info}"
    end

    private

    def analyze_code(code, binding = Object::TOPLEVEL_BINDING)
      # Workaround for https://github.com/ruby/prism/issues/1592
      return if code.match?(/%[qQ]\z/)

      ast = Prism.parse(code, scopes: [binding.local_variables]).value
      name = code[/(@@|@|\$)?\w*[!?=]?\z/]
      *parents, target_node = find_target ast, code.bytesize - name.bytesize
      return unless target_node

      calculate_scope = -> { TypeAnalyzer.calculate_target_type_scope(binding, parents, target_node).last }
      calculate_type_scope = ->(node) { TypeAnalyzer.calculate_target_type_scope binding, [*parents, target_node], node }

      case target_node
      when Prism::StringNode, Prism::InterpolatedStringNode
        call_node, args_node = parents.last(2)
        return unless call_node.is_a?(Prism::CallNode) && call_node.receiver.nil?
        return unless args_node.is_a?(Prism::ArgumentsNode) && args_node.arguments.size == 1

        case call_node.name
        when :require
          [:require, name]
        when :require_relative
          [:require_relative, name]
        end
      when Prism::SymbolNode
        if parents.last.is_a? Prism::BlockArgumentNode # method(&:target)
          receiver_type, _scope = calculate_type_scope.call target_node
          [:call, name, receiver_type, false]
        else
          [:symbol, name] unless name.empty?
        end
      when Prism::CallNode
        return [:lvar_or_method, name, calculate_scope.call] if target_node.receiver.nil?

        self_call = target_node.receiver.is_a? Prism::SelfNode
        op = target_node.call_operator
        receiver_type, _scope = calculate_type_scope.call target_node.receiver
        receiver_type = receiver_type.nonnillable if op == '&.'
        [op == '::' ? :call_or_const : :call, name, receiver_type, self_call]
      when Prism::LocalVariableReadNode, Prism::LocalVariableTargetNode
        [:lvar_or_method, name, calculate_scope.call]
      when Prism::ConstantReadNode, Prism::ConstantTargetNode
        if parents.last.is_a? Prism::ConstantPathNode
          path_node = parents.last
          if path_node.parent # A::B
            receiver, scope = calculate_type_scope.call(path_node.parent)
            [:const, name, receiver, scope]
          else # ::A
            scope = calculate_scope.call
            [:const, name, Types::SingletonType.new(Object), scope]
          end
        else
          [:const, name, nil, calculate_scope.call]
        end
      when Prism::GlobalVariableReadNode, Prism::GlobalVariableTargetNode
        [:gvar, name, calculate_scope.call]
      when Prism::InstanceVariableReadNode, Prism::InstanceVariableTargetNode
        [:ivar, name, calculate_scope.call]
      when Prism::ClassVariableReadNode, Prism::ClassVariableTargetNode
        [:cvar, name, calculate_scope.call]
      end
    end

    def find_target(node, position)
      location = (
        case node
        when Prism::CallNode
          node.message_loc
        when Prism::SymbolNode
          node.value_loc
        when Prism::StringNode
          node.content_loc
        when Prism::InterpolatedStringNode
          node.closing_loc if node.parts.empty?
        end
      )
      return [node] if location&.start_offset == position

      node.compact_child_nodes.each do |n|
        match = find_target(n, position)
        next unless match
        match.unshift node
        return match
      end

      [node] if node.location.start_offset == position
    end
  end
end

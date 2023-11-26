# frozen_string_literal: true

require 'repl_completion'
require_relative './helper'

module TestReplCompletion
  class ReplCompletionTest < TestCase
    def setup
      ReplCompletion.load_rbs unless ReplCompletion.rbs_loaded?
    end

    def empty_binding
      binding
    end

    TARGET_REGEXP = /(@@|@|\$)?[a-zA-Z_]*[!?=]?$/

    def assert_completion(code, binding: empty_binding, include: nil, exclude: nil)
      raise ArgumentError if include.nil? && exclude.nil?
      candidates = ReplCompletion.analyze(code, binding).completion_candidates
      assert ([*include] - candidates).empty?, "Expected #{candidates} to include #{include}" if include
      assert (candidates & [*exclude]).empty?, "Expected #{candidates} not to include #{exclude}" if exclude
    end

    def assert_doc_namespace(code, namespace, binding: empty_binding)
      assert_equal namespace, ReplCompletion.analyze(code, binding).doc_namespace('')
    end

    def test_require
      assert_completion("require '", include: 'set')
      assert_completion("require 's", include: 'et')
      assert_completion("require_relative 'test_", include: 'repl_completion')
      # Incomplete double quote string is InterpolatedStringNode
      assert_completion('require "', include: 'set')
      assert_completion('require "s', include: 'et')
    end

    def test_method_block_sym
      assert_completion('[1].map(&:', include: 'abs')
      assert_completion('[:a].map(&:', exclude: 'abs')
      assert_completion('[1].map(&:a', include: 'bs')
      assert_doc_namespace('[1].map(&:abs', 'Integer#abs')
    end

    def test_symbol
      prefix = ':test_com'
      sym = :test_completion_symbol
      assert_completion(prefix, include: sym.inspect.delete_prefix(prefix))
    end

    def test_call
      assert_completion('1.', include: 'abs')
      assert_completion('1.a', include: 'bs')
      assert_completion('ran', include: 'd')
      assert_doc_namespace('1.abs', 'Integer#abs')
      assert_doc_namespace('Integer.sqrt', 'Integer.sqrt')
      assert_doc_namespace('rand', 'TestReplCompletion::ReplCompletionTest#rand')
      assert_doc_namespace('Object::rand', 'Object.rand')
    end

    def test_lvar
      bind = eval('lvar = 1; binding')
      assert_completion('lva', binding: bind, include: 'r')
      assert_completion('lvar.', binding: bind, include: 'abs')
      assert_completion('lvar.a', binding: bind, include: 'bs')
      assert_completion('lvar = ""; lvar.', binding: bind, include: 'ascii_only?')
      assert_completion('lvar = ""; lvar.', include: 'ascii_only?')
      assert_doc_namespace('lvar', 'Integer', binding: bind)
      assert_doc_namespace('lvar.abs', 'Integer#abs', binding: bind)
      assert_doc_namespace('lvar = ""; lvar.ascii_only?', 'String#ascii_only?', binding: bind)
    end

    def test_const
      assert_completion('Ar', include: 'ray')
      assert_completion('::Ar', include: 'ray')
      assert_completion('ReplCompletion::V', include: 'ERSION')
      assert_completion('FooBar=1; F', include: 'ooBar')
      assert_completion('::FooBar=1; ::F', include: 'ooBar')
      assert_doc_namespace('Array', 'Array')
      assert_doc_namespace('Array = 1; Array', 'Integer')
      assert_doc_namespace('Object::Array', 'Array')
      assert_completion('::', include: 'Array')
      assert_completion('class ::', include: 'Array')
      assert_completion('module ReplCompletion; class T', include: ['ypes', 'racePoint'])
    end

    def test_gvar
      assert_completion('$', include: 'stdout')
      assert_completion('$s', include: 'tdout')
      assert_completion('$', exclude: 'foobar')
      assert_completion('$foobar=1; $', include: 'foobar')
      assert_doc_namespace('$foobar=1; $foobar', 'Integer')
      assert_doc_namespace('$stdout', 'IO')
      assert_doc_namespace('$stdout=1; $stdout', 'Integer')
    end

    def test_ivar
      bind = Object.new.instance_eval { @foo = 1; binding }
      assert_completion('@', binding: bind, include: 'foo')
      assert_completion('@f', binding: bind, include: 'oo')
      assert_completion('@bar = 1; @', include: 'bar')
      assert_completion('@bar = 1; @b', include: 'ar')
      assert_doc_namespace('@bar = 1; @bar', 'Integer')
      assert_doc_namespace('@foo', 'Integer', binding: bind)
      assert_doc_namespace('@foo = 1.0; @foo', 'Float', binding: bind)
    end

    def test_cvar
      bind = eval('m=Module.new; module m::M; @@foo = 1; binding; end')
      assert_equal(1, bind.eval('@@foo'))
      assert_completion('@', binding: bind, include: '@foo')
      assert_completion('@@', binding: bind, include: 'foo')
      assert_completion('@@f', binding: bind, include: 'oo')
      assert_doc_namespace('@@foo', 'Integer', binding: bind)
      assert_doc_namespace('@@foo = 1.0; @@foo', 'Float', binding: bind)
      assert_completion('@@bar = 1; @', include: '@bar')
      assert_completion('@@bar = 1; @@', include: 'bar')
      assert_completion('@@bar = 1; @@b', include: 'ar')
      assert_doc_namespace('@@bar = 1; @@bar', 'Integer')
    end

    def test_basic_object
      bo = BasicObject.new
      def bo.foo; end
      bo.instance_eval { @bar = 1 }
      bind = binding
      bo_self_bind = bo.instance_eval { Kernel.binding }
      assert_completion('bo.', binding: bind, include: 'foo')
      assert_completion('def bo.baz; self.', binding: bind, include: 'foo')
      assert_completion('[bo].first.', binding: bind, include: 'foo')
      assert_doc_namespace('bo', 'BasicObject', binding: bind)
      assert_doc_namespace('bo.__id__', 'BasicObject#__id__', binding: bind)
      assert_doc_namespace('v = [bo]; v', 'Array', binding: bind)
      assert_doc_namespace('v = [bo].first; v', 'BasicObject', binding: bind)
      bo_self_bind = bo.instance_eval { Kernel.binding }
      assert_completion('self.', binding: bo_self_bind, include: 'foo')
      assert_completion('@', binding: bo_self_bind, include: 'bar')
      assert_completion('@bar.', binding: bo_self_bind, include: 'abs')
      assert_doc_namespace('self.__id__', 'BasicObject#__id__', binding: bo_self_bind)
      assert_doc_namespace('@bar', 'Integer', binding: bo_self_bind)
      if RUBY_VERSION >= '3.2.0' # Needs Class#attached_object to get instance variables from singleton class
        assert_completion('def bo.baz; @bar.', binding: bind, include: 'abs')
        assert_completion('def bo.baz; @', binding: bind, include: 'bar')
      end
    end

    DEPRECATED_CONST = 1
    deprecate_constant :DEPRECATED_CONST
    def test_deprecated_const_without_warning
      assert_deprecated_warning(/\A\z/) do
        assert_completion('DEPRECATED', include: '_CONST', binding: binding)
        assert_completion('DEPRECATED_CONST.a', include: 'bs', binding: binding)
        assert_doc_namespace('DEPRECATED_CONST', 'Integer', binding: binding)
      end
    end

    def test_sig_dir
      assert_doc_namespace('ReplCompletion.analyze(code, binding).completion_candidates.__id__', 'Array#__id__')
      assert_doc_namespace('ReplCompletion.analyze(code, binding).doc_namespace.__id__', 'String#__id__')
    end

    def test_none
      result = ReplCompletion.analyze('()', binding)
      assert_nil result
    end

    def test_repl_completion_api
      assert_nil ReplCompletion.rbs_load_error
      assert_nil ReplCompletion.last_completion_error
      assert_equal true, ReplCompletion.rbs_load_started?
      assert_equal true, ReplCompletion.rbs_loaded?
      assert_nothing_raised { ReplCompletion.preload_rbs }
      assert_nothing_raised { ReplCompletion.load_rbs }
    end

    def with_failing_method(klass, method_name, message)
      original_method = klass.instance_method(method_name)
      klass.remove_method(method_name)
      klass.define_method(method_name) do |*, **|
        raise Exception.new(message)
      end
      yield
    ensure
      klass.remove_method(method_name)
      klass.define_method(method_name, original_method)
    end

    def test_analyze_error
      with_failing_method(ReplCompletion.singleton_class, :analyze_code, 'error_in_analyze_code') do
        assert_nil ReplCompletion.analyze '1.', binding
      end
      assert_equal 'error_in_analyze_code', ReplCompletion.last_completion_error&.message
    ensure
      ReplCompletion.instance_variable_set(:@last_completion_error, nil)
    end

    def test_completion_candidates_error
      result = ReplCompletion.analyze '1.', binding
      with_failing_method(ReplCompletion::Types::InstanceType, :methods, 'error_in_methods') do
        assert_equal [], result.completion_candidates
      end
      assert_equal 'error_in_methods', ReplCompletion.last_completion_error&.message
    ensure
      ReplCompletion.instance_variable_set(:@last_completion_error, nil)
    end

    def test_doc_namespace_error
      result = ReplCompletion.analyze '1.', binding
      with_failing_method(ReplCompletion::Result, :method_doc, 'error_in_method_doc') do
        assert_nil result.doc_namespace('abs')
      end
      assert_equal 'error_in_method_doc', ReplCompletion.last_completion_error&.message
    ensure
      ReplCompletion.instance_variable_set(:@last_completion_error, nil)
    end

    def test_info
      assert_equal "ReplCompletion: #{ReplCompletion::VERSION}, Prism: #{Prism::VERSION}, RBS: #{RBS::VERSION}", ReplCompletion.info
    end
  end
end

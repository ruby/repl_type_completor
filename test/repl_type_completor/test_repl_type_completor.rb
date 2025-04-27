# frozen_string_literal: true

require 'repl_type_completor'
require_relative './helper'

module TestReplTypeCompletor
  class ReplTypeCompletorTest < TestCase
    def setup
      ReplTypeCompletor.load_rbs unless ReplTypeCompletor.rbs_loaded?
    end

    def teardown
      if ReplTypeCompletor.last_completion_error
        raise ReplTypeCompletor.last_completion_error
        ReplTypeCompletor.instance_variable_set(:@last_completion_error, nil)
      end
    end

    def empty_binding
      binding
    end

    TARGET_REGEXP = /(@@|@|\$)?[a-zA-Z_]*[!?=]?$/

    def assert_completion(code, binding: empty_binding, filename: nil, include: nil, exclude: nil)
      raise ArgumentError if include.nil? && exclude.nil?
      candidates = ReplTypeCompletor.analyze(code, binding: binding, filename: filename).completion_candidates
      assert ([*include] - candidates).empty?, "Expected #{candidates} to include #{include}" if include
      assert (candidates & [*exclude]).empty?, "Expected #{candidates} not to include #{exclude}" if exclude
    end

    def assert_doc_namespace(code, namespace, binding: empty_binding)
      assert_equal namespace, ReplTypeCompletor.analyze(code, binding: binding).doc_namespace('')
    end

    def test_require
      assert_completion("require '", include: 'repl_type_completor')
      assert_completion("require 'r", include: 'epl_type_completor')
      assert_completion('require "', include: 'repl_type_completor')
      assert_completion('require "r', include: 'epl_type_completor')
      assert_completion('require_relative "r', exclude: 'epl_type_completor')
      assert_completion("require_relative 'test_", filename: __FILE__, include: 'repl_type_completor')
      assert_completion("require_relative '../repl_", filename: __FILE__, include: 'type_completor/test_repl_type_completor')
      Dir.chdir File.join(__dir__, '..') do
        assert_completion("require_relative 'repl_", filename: nil, include: 'type_completor/test_repl_type_completor')
        assert_completion("require_relative 'repl_", filename: '(irb)', include: 'type_completor/test_repl_type_completor')
      end

      # Should not complete terminated string
      assert_nil ReplTypeCompletor.analyze('require "s"', binding: empty_binding)
      assert_nil ReplTypeCompletor.analyze('require ?s', binding: empty_binding)
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

    def test_symbol_limit
      result = ReplTypeCompletor::Result.new([:symbol, 'sym'], binding, 'file')
      symbols = [:ae, :ad, :ab1, :ab2, :ac, :aa, :b, :"a a", 75.chr('utf-7').to_sym]
      assert_equal(%w[aa ab1 ab2 ac ad ae], result.send(:filter_symbol_candidates, symbols, 'a', limit: 100))
      assert_equal(%w[aa ab1 ab2 ad ae], result.send(:filter_symbol_candidates, symbols, 'a', limit: 5))
      assert_equal(%w[aa ab1 ad ae], result.send(:filter_symbol_candidates, symbols, 'a', limit: 4))
      assert_equal(%w[ab1 ab2], result.send(:filter_symbol_candidates, symbols, 'ab', limit: 4))
      assert_equal([], result.send(:filter_symbol_candidates, symbols, 'c', limit: 4))
    end

    def test_call
      assert_completion('1.', include: 'abs')
      assert_completion('1.a', include: 'bs')
      assert_completion('ran', include: 'd')
      assert_doc_namespace('1.abs', 'Integer#abs')
      assert_doc_namespace('Integer.sqrt', 'Integer.sqrt')
      assert_doc_namespace('rand', 'TestReplTypeCompletor::ReplTypeCompletorTest#rand')
      assert_doc_namespace('Object::rand', 'Object.rand')
    end

    def test_closed_no_completion
      # `:"bin"` should not complete `:"bin"ding`
      assert_nil(ReplTypeCompletor.analyze(':"bin"', binding: binding))
      # `ex()` should not complete `ex()it`
      assert_nil(ReplTypeCompletor.analyze('ex()', binding: binding))
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

    def test_confusing_lvar_method_it
      bind = eval('item = 1; ins=1; random = 1; binding')
      assert_completion('->{it', binding: bind, include: ['em', 'self'])
      assert_completion('->{ins', binding: bind, include: 'pect')
      assert_completion('->{rand', binding: bind, include: 'om')
    end

    def test_const
      assert_completion('Ar', include: 'ray')
      assert_completion('::Ar', include: 'ray')
      assert_completion('ReplTypeCompletor::V', include: 'ERSION')
      assert_completion('FooBar=1; F', include: 'ooBar')
      assert_completion('::FooBar=1; ::F', include: 'ooBar')
      assert_doc_namespace('Array', 'Array')
      assert_doc_namespace('Array = 1; Array', 'Integer')
      assert_doc_namespace('Object::Array', 'Array')
      assert_completion('::', include: 'Array')
      assert_completion('class ::', include: 'Array')
      assert_completion('module ReplTypeCompletor; class T', include: ['ypes', 'racePoint'])
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

    def test_anonymous_class
      bind = eval('c = Struct.new(:foobar); o = c.new; binding')
      assert_completion('c.', binding: bind, include: ['ancestors', 'singleton_class?', 'superclass'])
      assert_completion('o.', binding: bind, include: ['foobar', 'each_pair'])
      assert_doc_namespace('c.superclass', 'Struct.superclass', binding: bind)
      assert_doc_namespace('o.each', 'Struct#each', binding: bind)
    end

    def test_anonymous_module
      bind = eval('m = Module.new; binding')
      assert_completion('m.', binding: bind, include: ['ancestors', 'singleton_class?'], exclude: 'superclass')
      assert_doc_namespace('m.ancestors', 'Module.ancestors', binding: bind)
    end

    def test_array_singleton_method
      assert_completion('$LOAD_PATH.', include: 'resolve_feature_path')
      assert_completion('$LOAD_PATH.itself.', include: 'resolve_feature_path')
      assert_completion('[$LOAD_PATH].first.', include: 'resolve_feature_path')
      assert_completion('{ x: $LOAD_PATH }.each_value { _1.', include: 'resolve_feature_path')
    end

    def test_recursive_array
      a = Object.new
      b = Object.new
      def a.foobar; end
      def b.foobaz; end
      arr = [a, [b]]
      arr[1] << arr
      bind = binding
      assert_completion('arr.sample.foo', binding: bind, include: 'bar', exclude: 'baz')
      assert_completion('arr.sample.sample.foo', binding: bind, include: 'baz', exclude: 'bar')
      assert_completion('arr.sample.sample.sample.foo', binding: bind, include: 'bar', exclude: 'baz')
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
      assert_doc_namespace('ReplTypeCompletor.analyze(code, binding: binding).completion_candidates.__id__', 'Array#__id__')
      assert_doc_namespace('ReplTypeCompletor.analyze(code, binding: binding).doc_namespace.__id__', 'String#__id__')
    end

    def test_none
      result = ReplTypeCompletor.analyze('()', binding: binding)
      assert_nil result
    end

    def test_repl_type_completor_api
      assert_nil ReplTypeCompletor.rbs_load_error
      assert_nil ReplTypeCompletor.last_completion_error
      assert_equal true, ReplTypeCompletor.rbs_load_started?
      assert_equal true, ReplTypeCompletor.rbs_loaded?
      assert_nothing_raised { ReplTypeCompletor.preload_rbs }
      assert_nothing_raised { ReplTypeCompletor.load_rbs }
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
      with_failing_method(ReplTypeCompletor.singleton_class, :analyze_code, 'error_in_analyze_code') do
        assert_nil ReplTypeCompletor.analyze('1.', binding: binding)
      end
      assert_equal 'error_in_analyze_code', ReplTypeCompletor.last_completion_error&.message
    ensure
      ReplTypeCompletor.instance_variable_set(:@last_completion_error, nil)
    end

    def test_completion_candidates_error
      result = ReplTypeCompletor.analyze '1.', binding: binding
      with_failing_method(ReplTypeCompletor::Types::InstanceType, :methods, 'error_in_methods') do
        assert_equal [], result.completion_candidates
      end
      assert_equal 'error_in_methods', ReplTypeCompletor.last_completion_error&.message
    ensure
      ReplTypeCompletor.instance_variable_set(:@last_completion_error, nil)
    end

    def test_doc_namespace_error
      result = ReplTypeCompletor.analyze '1.', binding: binding
      with_failing_method(ReplTypeCompletor::Result, :method_doc, 'error_in_method_doc') do
        assert_nil result.doc_namespace('abs')
      end
      assert_equal 'error_in_method_doc', ReplTypeCompletor.last_completion_error&.message
    ensure
      ReplTypeCompletor.instance_variable_set(:@last_completion_error, nil)
    end

    def test_loaded_gem_types
      # gem_dir/sig directory does not exist when running with `make test-bundled-gems`
      omit unless Dir.exist?("#{Gem.loaded_specs['rbs'].gem_dir}/sig")

      result = ReplTypeCompletor.analyze 'RBS::CLI::LibraryOptions.new.loader.', binding: binding
      candidtes = result.completion_candidates
      assert_includes candidtes, 'add'
    end

    def test_info
      assert_equal "ReplTypeCompletor: #{ReplTypeCompletor::VERSION}, Prism: #{Prism::VERSION}, RBS: #{RBS::VERSION}", ReplTypeCompletor.info
    end
  end
end

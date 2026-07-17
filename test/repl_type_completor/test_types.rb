# frozen_string_literal: true

require 'repl_type_completor'
require_relative './helper'

module TestReplTypeCompletor
  class TypesTest < TestCase
    def test_type_inspect
      true_type = ReplTypeCompletor::Types::TRUE
      false_type = ReplTypeCompletor::Types::FALSE
      nil_type = ReplTypeCompletor::Types::NIL
      string_type = ReplTypeCompletor::Types::STRING
      true_or_false = ReplTypeCompletor::Types::UnionType[true_type, false_type]
      array_type = ReplTypeCompletor::Types::InstanceType.new(Array, [true_or_false])
      assert_equal 'nil', nil_type.inspect
      assert_equal 'true', true_type.inspect
      assert_equal 'false', false_type.inspect
      assert_equal 'String', string_type.inspect
      assert_equal 'Array', ReplTypeCompletor::Types::InstanceType.new(Array).inspect
      assert_equal 'false | true', true_or_false.inspect
      assert_include ['Array[E: false | true]', 'Array[Elem: false | true]'], array_type.inspect
      assert_equal 'Array', array_type.inspect_without_params
      assert_equal 'Proc', ReplTypeCompletor::Types::PROC.inspect
      assert_equal 'Array.itself', ReplTypeCompletor::Types::SingletonType.new(Array).inspect
    end

    def test_type_from_object
      obj = Object.new
      bo = BasicObject.new
      def bo.hash; 42; end # Needed to use this object as a hash key
      arr = [1, 'a']
      hash = { 'key' => :value }
      int_type = ReplTypeCompletor::Types.type_from_object 1
      obj_type = ReplTypeCompletor::Types.type_from_object obj
      arr_type = ReplTypeCompletor::Types.type_from_object arr
      hash_type = ReplTypeCompletor::Types.type_from_object hash
      bo_type = ReplTypeCompletor::Types.type_from_object bo
      bo_arr_type = ReplTypeCompletor::Types.type_from_object [bo]
      bo_key_hash_type = ReplTypeCompletor::Types.type_from_object({ bo => 1 })
      bo_value_hash_type = ReplTypeCompletor::Types.type_from_object({ x: bo })

      assert_equal Integer, int_type.klass
      # Type contains actual instances to autocomplete singleton methods
      assert_equal Object, obj_type.klass
      assert_equal [obj], obj_type.instances
      assert_equal BasicObject, bo_type.klass
      assert_equal [bo], bo_type.instances
      # Array and Hash are special
      assert_equal Array, arr_type.klass
      assert_equal Array, bo_arr_type.klass
      assert_equal Hash, hash_type.klass
      assert_equal Hash, bo_key_hash_type.klass
      assert_equal Hash, bo_value_hash_type.klass
      assert_equal BasicObject, bo_arr_type.params[0].klass
      assert_equal BasicObject, bo_key_hash_type.params[0].klass
      assert_equal BasicObject, bo_value_hash_type.params[1].klass
      assert_equal 'Object', obj_type.inspect
      assert_equal 'Array[unresolved]', arr_type.inspect
      assert_include ['Array[E: Integer | String]', 'Array[Elem: Integer | String]'], arr_type.tap(&:params).inspect
      assert_equal 'Hash[unresolved]', hash_type.inspect
      assert_equal 'Hash[K: String, V: Symbol]', hash_type.tap(&:params).inspect
      assert_equal 'Array.itself', ReplTypeCompletor::Types.type_from_object(Array).inspect
      assert_equal 'ReplTypeCompletor.itself', ReplTypeCompletor::Types.type_from_object(ReplTypeCompletor).inspect
    end

    def test_type_methods
      s = +''
      class << s
        def foobar; end
        private def foobaz; end
      end
      String.define_method(:foobarbaz) {}
      targets = [:foobar, :foobaz, :foobarbaz, :rand]
      type = ReplTypeCompletor::Types.type_from_object s
      assert_equal [:foobar, :foobarbaz], targets & type.methods
      assert_equal [:foobar, :foobaz, :foobarbaz, :rand], targets & type.all_methods
      assert_equal [:foobarbaz], targets & ReplTypeCompletor::Types::STRING.methods
      assert_equal [:foobarbaz, :rand], targets & ReplTypeCompletor::Types::STRING.all_methods
    ensure
      String.remove_method :foobarbaz
    end

    def test_singleton_type_methods
      m = Module.new do
        class << self
          def foobar; end
          private def foobaz; end
        end
      end
      type = ReplTypeCompletor::Types::SingletonType.new(m)
      assert_include type.methods, :foobar
      assert_not_include type.methods, :foobaz
      assert_include type.all_methods, :foobaz
      assert_include type.all_methods, :rand
    end

    def type_from_rbs(rbs_string)
      ReplTypeCompletor::Types.load_rbs_builder unless ReplTypeCompletor::Types.rbs_builder
      rbs_type = RBS::Parser.parse_type(rbs_string)
      ReplTypeCompletor::Types.from_rbs_type(rbs_type, ReplTypeCompletor::Types::OBJECT)
    end

    def test_interface_type
      to_int = type_from_rbs('::_ToInt')
      assert_equal '_ToInt', to_int.inspect
      assert_equal [:to_int], to_int.methods
      assert ReplTypeCompletor::Types.intersect?(ReplTypeCompletor::Types::FLOAT, to_int)
      assert ReplTypeCompletor::Types.intersect?(to_int, ReplTypeCompletor::Types::FLOAT)
      refute ReplTypeCompletor::Types.intersect?(ReplTypeCompletor::Types::STRING, to_int)

      to_ary = type_from_rbs('::_ToAry[::Integer]')
      assert_equal '_ToAry[Integer]', to_ary.inspect
      return_type = ReplTypeCompletor::Types.method_return_type(to_ary, :to_ary)
      assert_equal Array, return_type.klass
      assert_equal Integer, return_type.params[0].klass
    end

    def test_alias_type_expansion
      int_type = type_from_rbs('::int')
      assert_equal 'Integer | _ToInt', int_type.inspect
    end

    def test_basic_object_methods
      bo = BasicObject.new
      def bo.foobar; end
      type = ReplTypeCompletor::Types.type_from_object bo
      assert type.all_methods.include?(:foobar)
    end

    def test_params_lazily_expanded_on_recursive_type
      deepest = [{ 1 => 2.0 }]
      a = deepest
      5.times { a = ['even', [:odd, a]] }
      deepest << a
      type = ReplTypeCompletor::Types.type_from_object a
      assert_equal Array, type.klass
      10.times do |i|
        elem_type = type.params[0]
        expected = i.even? ? [Array, String] : [Array, Symbol]
        assert_equal expected, elem_type.types.map(&:klass).sort_by(&:name)
        type = elem_type.types.find { _1.klass == Array }
      end
      hash_type = type.params[0].types.find { _1.klass == Hash }
      assert_equal 'Hash[unresolved]', hash_type.inspect
      assert_equal 'Hash[K: Integer, V: Float]', hash_type.tap(&:params).inspect
    end

    def test_infinite_nested_type_inspect
      a = []
      a << a
      type = ReplTypeCompletor::Types.type_from_object a
      assert_equal 'Array[unresolved]', type.inspect
      assert_include ['Array[E: Array[unresolved]]', 'Array[Elem: Array[unresolved]]'], type.tap(&:params).inspect
    end
  end
end

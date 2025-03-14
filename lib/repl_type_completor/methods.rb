# frozen_string_literal: true

module ReplTypeCompletor
  module Methods
    OBJECT_SINGLETON_METHODS_METHOD = Object.instance_method(:singleton_methods)
    OBJECT_PRIVATE_METHODS_METHOD = Object.instance_method(:private_methods)
    OBJECT_INSTANCE_VARIABLES_METHOD = Object.instance_method(:instance_variables)
    OBJECT_INSTANCE_VARIABLE_GET_METHOD = Object.instance_method(:instance_variable_get)
    OBJECT_CLASS_METHOD = Object.instance_method(:class)
    MODULE_NAME_METHOD = Module.instance_method(:name)
  end
end

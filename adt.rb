module Adt
  module Exception
    class BaseAdtException < StandardError; end
    class AdtTypeRequired < BaseAdtException; end
    class AbstractMethodMustBeImplemented < BaseAdtException; end
    class CannotInitializeDirectly < BaseAdtException; end
    class UnknownType < BaseAdtException; end
    class TypeConstructorExceptoin < BaseAdtException; end

    module TypeConstructor
      class BaseTypeConstructorException < BaseAdtException; end
      class ClassMustBeInherited < BaseTypeConstructorException; end
      class ArityViolation < BaseTypeConstructorException; end
      class TypeMismatched < BaseTypeConstructorException; end
    end
  end

  class TypeDef
    attr_reader :value

    def initialize(value)
      @value = spawn(value)
    end

    def ==(other)
      other.instance_of?(self.class) && value == other.value
    end

    protected

    def spwan(value)
      raise AdtException::AbstractMethodMustBeImplemented
    end
  end

  class TypeParams
    def initialize(*type_params)
      precondition(type_params)
      @type_params = Internal::Tuple.new(*type_params)
    end

    def inspect
      @type_params.elements
    end

    def arity
      @type_params.size
    end

    private

    def precondition(type_params)
      type_params.each do |t|
        begin
          validated = t < TypeDef
        rescue ArgumentError
          validated = false
        end
        raise Exception::AdtTypeRequired unless validated
      end
    end
  end

  module TypeConstructor
    class << self
      def define(&factory)
        created = factory.call(Template)
        raise Exception::TypeConstructorClassMustBeInherited unless created < Template
        created
      end

      def bind(type, param_types)
        params = type.instance_method(:initialize).parameters
        raise Exception::TypeConstructor::ArityViolation if params.size != param_types.size
        type
      end
    end

    class Template
      def self.name
        class_variable_get(:@@name)
      end
    end
  end

  class Data
    def initialize
      raise Exception::CannotInitializeDirectly
    end

    class << self
      def type(name, param_types, &typebody)
        register(name, param_types, TypeConstructor.define(&typebody))
      end

      def of(name)
        members[name.to_sym] || (raise Exception::UnknownType)
      end

      private

      def members
        @members ||= {}
      end

      def register(name, param_types, member)
        members[name.to_sym] = member
        member.class_variable_set(:@@name, name)
        TypeConstructor.bind(member, param_types)
      end
    end

    private

    def check_args
    end
  end

  module Internal
    class Tuple
      include Enumerable

      attr_reader :elements

      def initialize(*args)
        @elements = args.freeze
      end

      def [](i)
        @elements[i]
      end
    end
  end
end

require './adt.rb'

module AdtTestHelper
  module Presentation
    def self.colored(color_code, msg)
      "\e[#{color_code}m#{msg}\e[0m"
    end

    COLORED_STRING = {
      red: -> (msg) { colored(31, msg) },
      green: -> (msg) { colored(32, msg) },
      blue: -> (msg) { colored(34, msg) }
    }

    class ResultRenderer
      def initialize(result, actual, expected)
        @result = result
        @actual = actual
        @expected = expected
      end

      def label
        { true => 'passed', false => 'failed' }[@result]
      end

      def color
        { true => COLORED_STRING[:green], false => COLORED_STRING[:red] }[@result]
      end

      def to_s
        failed_detail = if @result == true
                          ""
                        else
                          "expected `#{@expected}` but `#{@actual}`"
                        end
        color.call("result: #{label} #{failed_detail}")
      end
    end
  end
  module Assertion
    module_function

    def assert(test_name, expected)
      puts "=== #{test_name} ==="
      begin
        result, actual = yield
      rescue StandardError => e
        detail = e.backtrace.map { |b| "\t\t#{b}" }.join("\n")
        puts "\t#{e.class} occurred. Detail:\n\n#{detail}"
        renderer = Presentation::ResultRenderer.new(false, 'An unexpected error occrued', expected)
      else
        renderer = Presentation::ResultRenderer.new(result, actual, expected)
      end
      puts "\t#{renderer.to_s}"
      result
    end

    def assert_eq(test_name, expected)
      assert(test_name, expected) do
        actual = yield
        [actual == expected, actual]
      end
    end

    def assert_raise(test_name, expected)
      assert(test_name, expected) do
        begin
          yield
        rescue expected
          [true, 'An expected error occurred']
        else
          [false, 'An expected error not occurr']
        end
      end
    end

    def assert_calm(test_name)
      assert(test_name, 'No exception assert') do
        begin
          yield
        rescue StandardError
            [false, 'An exception occurred']
        else
            [true, 'Done correctly']
        end
      end
    end
  end

  module Fixture
    class IntType < Adt::TypeDef
      protected

      def spawn(value)
        Integer(value)
      end
    end

    class StringType < Adt::TypeDef
      protected

      def spawn(value)
        String.new(value)
      end
    end

    class Example < Adt::Data
      type :NoParams, [] do |parent|
        Class.new(parent) do
          attr_reader :created_at

          def initialize
            @created_at = Time.now
          end

          def meth
            "I have an instance variable named created_at: #{@created_at}"
          end
        end
      end

      type :SingleParam, [IntType] do |parent|
        Class.new(parent) do
          attr_reader :value

          def initialize(value)
            @value = value
          end

          def meth
            "I have an instance variable: #{@value}"
          end
        end
      end

      type :MultiParams, [IntType, StringType] do |parent|
        Class.new(parent) do
          attr_reader :int_value, :string_value

          def initialize(int_value, string_value)
            @int_value = int_value
            @string_value = string_value
          end

          def meth
            "I have a instance variable named int_value: #{@int_value} and string_value #{@string_value}"
          end
        end
      end
    end
  end

  class Runner
    def initialize
      @passed = 0
      @total = 0
      @failed = []
    end
    def run(context)
      context.private_methods
        .filter { |f| f.to_s.start_with?('test_') }
        .each do |t|
          @total += 1
          if send(t)
            @passed+= 1
          else
            @failed << t
          end
        end
      report
    end

    def report
      msg = "TOTAL: #{@total} / PASSED: #{@passed}"
      puts Presentation::COLORED_STRING[:blue].call(msg)
      puts Presentation::COLORED_STRING[:red].call("FAILED: #{@failed.join(',')}") if @failed.any?
    end
  end
end

Fixture = AdtTestHelper::Fixture
Assertion = AdtTestHelper::Assertion

def test_type_def
  value = 1
  actual = Fixture::IntType.new(value)
  Assertion.assert_eq('Adt::TypeDef', value) { actual.value }
  Assertion.assert_eq('Adt::TypeDef equation', true) { actual == Fixture::IntType.new(value) }
end

def test_type_params_abnormal
  Assertion.assert_raise('Adt::TypeParams invalid [instance value]', Adt::Exception::AdtTypeRequired) { Adt::TypeParams.new(1) }
  Assertion.assert_raise('Adt::TypeParams invalid [invalid type]', Adt::Exception::AdtTypeRequired) { Adt::TypeParams.new(Object) }
end

def test_type_params_normal
  Assertion::assert_eq('Adt::TypeParams can be instantiated from empty param', []) { Adt::TypeParams.new().inspect }
  passed_types = [Fixture::IntType, Fixture::StringType]
  Assertion.assert_eq('Adt::TypeParams can be instantiated from passed param', passed_types) { Adt::TypeParams.new(*passed_types).inspect }
end

def test_type_constructor_normal
  actual = Adt::TypeConstructor.define do |parent|
    Class.new(parent) do
      attr_reader :value

      def initialize(value)
        @value = value
      end
    end
  end
  value = 1
  Assertion.assert_eq('Adt::TypeConstructor instantiation', value) { actual.new(value).value }
end

def test_type_constructor_abnormal
  require 'pry';binding.pry
  Assertion.assert_raise('Adt::TypeConstructor directly initializing', Adt::Exception::CannotInitializeDirectly) { Adt::TypeConstructor.define { |_| Class.new { } } }
end

def test_data_normal
  no_params = Fixture::Example.of(:NoParams)
  Assertion.assert_calm('Adt::Data NoParams option') { no_params.new }

  single_param = Fixture::Example.of(:SingleParam)
  Assertion.assert_calm('Adt::Data SingleParam option') { single_param.new(Fixture::IntType.new(1)) }

  multi_params = Fixture::Example.of(:MultiParams)
  Assertion.assert_calm('Adt::Data MultiParams option') { multi_params.new(Fixture::IntType.new(1), Fixture::StringType.new('a')) }
end

def test_data_abnormal
  no_params = Fixture::Example.of(:NoParams)
  Assertion.assert_raise('Adt::Data NoParams arity violation', Adt::Exception::TypeConstructor::ArityViolation) { no_params.new(Fixture::IntType.new(1)) }

  single_param = Fixture::Example.of(:SingleParam)
  Assertion.assert_raise('Adt::Data SIngleParam arity violation: no params', Adt::Exception::TypeConstructor::ArityViolation) { single_param.new }
  Assertion.assert_raise('Adt::Data SIngleParam arity violation: more over', Adt::Exception::TypeConstructor::ArityViolation) { single_param.new(Fixture::IntType.new(1), Fixture::IntType.new(2)) }
  Assertion.assert_raise('Adt::Data SIngleParam mismatched type', Adt::Exception::TypeConstructor::ClassMustBeInherited) { single_param.new(Fixture::IntType.new(1), Fixture::IntType.new(2)) }

  multi_params = Fixture::Example.of(:MultiParams)
  Assertion.assert_raise('Adt::Data MultiParam arity violation: no params', Adt::Exception::TypeConstructor::ArityViolation) { multi_params.new }
  Assertion.assert_raise('Adt::Data MultiParam arity violation: lack', Adt::Exception::TypeConstructor::ArityViolation) { multi_params.new(Fixture::IntType.new(1)) }
  Assertion.assert_raise('Adt::Data MultiParam arity violation: more over', Adt::Exception::TypeConstructor::ArityViolation) { multi_params.new(Fixture::IntType.new(1), Fixture::StringType.new('a'), Fixture::IntType.new(2)) }
  Assertion.assert_raise('Adt::Data MultiParam mismatched type', Adt::Exception::TypeConstructor::ClassMustBeInherited) { multi_params.new(Fixture::IntType.new(1), Fixture::IntType.new(2)) }
end

AdtTestHelper::Runner.new.run(self)

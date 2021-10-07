# frozen_string_literal: true

module Paquito
  class SerializedColumn
    def initialize(coder, type = nil, attribute_name: nil)
      @coder = coder
      @type = type
      @attribute_name = attribute_name || "Attribute"
      check_arity_of_constructor
      @default_value = type&.new
    end

    def object_class
      @type || Object
    end

    def load(payload)
      return @type&.new if payload.nil?

      object = @coder.load(payload)
      check_type(object)
      object || @type&.new
    end

    def dump(object)
      return if object.nil? || object == @default_value

      check_type(object)
      @coder.dump(object)
    end

    private

    def check_arity_of_constructor
      load(nil)
    rescue ArgumentError
      raise ArgumentError,
        "Cannot serialize #{object_class}. Classes passed to `serialize` must have a 0 argument constructor."
    end

    def default_value?(object)
      object == @type&.new
    end

    def check_type(object)
      unless @type.nil? || object.is_a?(@type) || object.nil?
        raise ActiveRecord::SerializationTypeMismatch, "#{@attribute_name} was supposed to be a #{object_class}, " \
          "but was a #{object.class}. -- #{object.inspect}"
      end
    end
  end
end

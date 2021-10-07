# frozen_string_literal: true
require "paquito/errors"

module Paquito
  # To make a Struct class cacheable, include Paquito::Struct:
  #
  #   MyStruct = Struct.new(:foo, :bar)
  #   MyStruct.include(Paquito::Struct)
  #
  # Alternatively, declare the struct with Paquito::Struct#new:
  #
  #   MyStruct = Paquito::Struct.new(:foo, :bar)
  #
  # The struct defines #as_pack and .from_pack methods:
  #
  #   my_struct = MyStruct.new("foo", "bar")
  #   my_struct.as_pack
  #   => [26450, "foo", "bar"]
  #
  #   MyStruct.from_pack([26450, "foo", "bar"])
  #   => #<struct FooStruct foo="foo", bar="bar">
  #
  # The Paquito::Struct module can be used in non-Struct classes, so long
  # as the class:
  #
  # - defines a #values instance method
  # - defines a .members class method
  # - has an #initialize method that accepts the values as its arguments
  #
  # If the last condition is _not_ met, you can override .from_pack on the
  # class and initialize the instance however you like, optionally using the
  # private extract_packed_values method to extract values from the payload.
  #
  module Struct
    class << self
      def included(base)
        base.class_eval do
          @__kw_init__ = inspect.include?("keyword_init: true")
        end
        base.extend(ClassMethods)
      end
    end

    def as_pack
      [self.class.pack_digest, *values]
    end

    class << self
      def new(*members, keyword_init: false, &block)
        struct = ::Struct.new(*members, keyword_init: keyword_init, &block)
        struct.include(Paquito::Struct)
        struct
      end

      def digest(attr_names)
        ::Digest::MD5.digest(attr_names.map(&:to_s).join(",")).unpack1("s")
      end
    end

    module ClassMethods
      def from_pack(packed)
        values = extract_packed_values(packed, as_hash: @__kw_init__)

        if @__kw_init__
          new(**values)
        else
          new(*values)
        end
      end

      def pack_digest
        @pack_digest ||= ::Paquito::Struct.digest(members)
      end

      private

      def extract_packed_values(packed, as_hash:)
        digest, *values = packed
        if pack_digest != digest
          raise(VersionMismatchError, "#{self} digests do not match")
        end

        as_hash ? members.zip(values).to_h : values
      end
    end
  end
end

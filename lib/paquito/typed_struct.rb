# typed: true
# frozen_string_literal: true

return unless defined?(T::Props)

module Paquito
  # To make a T::Struct class serializable, include Paquito::TypedStruct:
  #
  #   class MyStruct < T::Struct
  #     include Paquito::TypedStruct
  #
  #     prop :foo, String
  #     prop :bar, Integer
  #   end
  #
  #   my_struct = MyStruct.new(foo: "foo", bar: 1)
  #   my_struct.as_pack
  #   => [26450, "foo", 1]
  #
  #   MyStruct.from_pack([26450, "foo", 1])
  #   => <MyStruct bar=1, foo="foo">
  #
  module TypedStruct
    extend T::Sig
    include T::Props::Plugin

    sig { returns(Array).checked(:never) }
    def as_pack
      decorator = self.class.decorator
      props = decorator.props.keys
      values = props.map { |prop| decorator.get(self, prop) }
      [self.class.pack_digest, *values]
    end

    module ClassMethods
      extend T::Sig

      sig { params(packed: Array).returns(T.untyped).checked(:never) }
      def from_pack(packed)
        digest, *values = packed
        if pack_digest != digest
          raise(VersionMismatchError, "#{self} digests do not match")
        end

        new(**props.keys.zip(values).to_h)
      end

      sig { returns(Integer).checked(:never) }
      def pack_digest
        @pack_digest ||= Paquito::Struct.digest(props.keys)
      end
    end
  end
end

# frozen_string_literal: true

require "test_helper"

class PaquitoTypedStructTest < PaquitoTest
  class FooStruct < T::Struct
    include Paquito::TypedStruct

    prop :foo, String
    prop :bar, Integer
  end

  test "#as_pack returns array of digest and struct values" do
    digest = pack_digest(FooStruct)

    assert_equal [digest, "foo", 1], FooStruct.new(foo: "foo", bar: 1).as_pack
  end

  test ".from_pack returns object from array of digest and struct values" do
    digest = pack_digest(FooStruct)

    unpacked = FooStruct.from_pack([digest, "foo", 1])
    assert_instance_of FooStruct, unpacked
    assert_equal "foo", unpacked.foo
    assert_equal 1, unpacked.bar
  end

  test ".from_pack raises VersionMismatchError when version does not match payload" do
    digest = pack_digest(FooStruct)

    FooStruct.from_pack([digest, "foo", 1])

    assert_raises(Paquito::VersionMismatchError) do
      FooStruct.from_pack([123, "foo", 1])
    end
  end

  private

  def pack_digest(klass)
    Paquito::Struct.digest(klass.props.keys)
  end
end

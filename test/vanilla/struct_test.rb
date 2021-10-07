# frozen_string_literal: true

require "test_helper"

class PaquitoStructTest < PaquitoTest
  FooStruct = Paquito::Struct.new(:foo, :bar)
  BarStruct = Paquito::Struct.new(:foo, :bar, keyword_init: true)
  BazStruct = Paquito::Struct.new(:baz, keyword_init: true)

  test "with keyword_init: false" do
    digest = pack_digest(FooStruct)
    assert_equal FooStruct.new("foo", "bar"), FooStruct.from_pack([digest, "foo", "bar"])

    instance = FooStruct.new("baz", "qux")
    assert_equal [digest, "baz", "qux"], instance.as_pack
  end

  test "with keyword_init: true" do
    digest = pack_digest(BarStruct)

    assert_equal BarStruct.new(foo: "foo", bar: "bar"), BarStruct.from_pack([digest, "foo", "bar"])
    instance = BarStruct.new(foo: "baz", bar: "qux")
    assert_equal [digest, "baz", "qux"], instance.as_pack
  end

  test "raises VersionMismatchError when version does not match payload" do
    digest = pack_digest(BazStruct)

    BazStruct.from_pack([digest, ["foo"]]) # nothing raised

    assert_raises(Paquito::VersionMismatchError) do
      BazStruct.from_pack([123, ["foo"]])
    end
  end

  test "accepts block argument" do
    struct = Paquito::Struct.new(:foo) do
      def bar
        "bar"
      end
    end
    instance = struct.new("foo")

    assert_equal "foo", instance.foo
    assert_equal "bar", instance.bar
  end

  private

  def pack_digest(klass)
    Paquito::Struct.digest(klass.members)
  end
end

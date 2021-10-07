# frozen_string_literal: true

require "test_helper"

class PaquitoSingleBytePrefixVersionTest < PaquitoTest
  def setup
    @coder = Paquito::SingleBytePrefixVersion.new(
      1,
      0 => YAML,
      1 => JSON,
      2 => MessagePack,
    )
  end

  test "#dump use the current version" do
    assert_equal "\x01{\"foo\":42}".b, @coder.dump({ foo: 42 })
  end

  test "#load respects the version prefix" do
    assert_equal({ foo: 42 }, @coder.load("\x00---\n:foo: 42"))
  end

  test "#load raises an error on unknown versions" do
    error = assert_raises(Paquito::UnsupportedCodec) do
      @coder.load("#{42.chr}blahblah")
    end
    assert_equal "Unsupported packer version 42", error.message
  end
end

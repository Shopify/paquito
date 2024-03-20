# frozen_string_literal: true

require "test_helper"

class PaquitoSingleBytePrefixVersionWithStringBypassTest < PaquitoTest
  def setup
    @coder = Paquito::SingleBytePrefixVersionWithStringBypass.new(
      1,
      { 0 => YAML, 1 => JSON, 2 => MessagePack },
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

  test "#load preserve string encoding" do
    utf8_str = "a" * 200
    assert_equal Encoding::UTF_8, utf8_str.encoding
    roundtrip = @coder.load(@coder.dump(utf8_str))
    assert_equal utf8_str, roundtrip
    assert_equal Encoding::UTF_8, roundtrip.encoding

    binary_str = Random.bytes(200)
    assert_equal Encoding::BINARY, binary_str.encoding
    roundtrip = @coder.load(@coder.dump(binary_str))
    assert_equal binary_str, roundtrip
    assert_equal Encoding::BINARY, binary_str.encoding

    ascii_str = ("a" * 200).force_encoding(Encoding::US_ASCII)
    assert_equal Encoding::US_ASCII, ascii_str.encoding
    roundtrip = @coder.load(@coder.dump(ascii_str))
    assert_equal ascii_str, roundtrip
    assert_equal Encoding::US_ASCII, ascii_str.encoding
  end

  test "supports multi-byte UTF-8" do
    utf8_str = "本"
    roundtrip = @coder.load(@coder.dump(utf8_str))
    assert_equal utf8_str, roundtrip
  end

  test "UTF8 version prefix is stable" do
    assert_equal "#{255.chr}foo", @coder.dump("foo")
  end

  test "BINARY version prefix is stable" do
    assert_equal "#{254.chr}foo", @coder.dump("foo".b)
  end

  test "ASCII version prefix is stable" do
    assert_equal "#{253.chr}foo", @coder.dump("foo".encode(Encoding::ASCII))
  end

  test "with a string_coder" do
    @coder_with_compression = Paquito::SingleBytePrefixVersionWithStringBypass.new(
      1,
      { 0 => YAML, 1 => JSON, 2 => MessagePack },
      Paquito::ConditionalCompressor.new(Zlib, 5),
    )
    assert_equal "#{255.chr}#{0.chr}foo".b, @coder_with_compression.dump("foo")
    str = "AAAAAAAAAAAA"
    assert_equal "#{255.chr}#{1.chr}#{Zlib.deflate(str)}".b, @coder_with_compression.dump(str)
  end
end

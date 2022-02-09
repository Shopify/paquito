# frozen_string_literal: true

require "test_helper"

class ConditionalCompressorTest < PaquitoTest
  def setup
    @coder = Paquito::ConditionalCompressor.new(
      Zlib,
      4,
    )
  end

  test "it does not compress when under the threshold" do
    assert_equal "\x00foo".b, @coder.dump("foo")
  end

  test "it does compress when over the threshold" do
    string = "foobar" * 25
    assert_equal "\x01#{Zlib.deflate(string)}".b, @coder.dump(string)
  end

  test "it does not compress if the compressed payload is larger" do
    string = "foobar"
    assert Zlib.deflate(string).bytesize > string.bytesize
    assert_equal "\x00#{string}".b, @coder.dump(string)
  end

  test "it decompress regardless of the size" do
    assert_equal "foo", @coder.load("\x01#{Zlib.deflate("foo")}")
    assert_equal "foobar", @coder.load("\x01#{Zlib.deflate("foobar")}")

    assert_equal "foo", @coder.load("\x00foo")
    assert_equal "foobar", @coder.load("\x00foobar")
  end

  test "it accept coders with the #deflate and #inflate interface" do
    @coder = Paquito::ConditionalCompressor.new(Zlib, 4)
    string = "foobar" * 25
    assert_equal "\x01#{Zlib.deflate(string)}".b, @coder.dump(string)
  end

  test "it raises UnpackError when the byte prefix is corrupted" do
    @coder = Paquito::ConditionalCompressor.new(Zlib, 4)
    error = assert_raises(Paquito::UnpackError) do
      @coder.load("\x02foobar".b)
    end
    assert_includes error.message, "invalid ConditionalCompressor version"
  end
end

# frozen_string_literal: true

require "test_helper"

class PaquitoCommentPrefixVersionTest < PaquitoTest
  def setup
    @coder = Paquito::CommentPrefixVersion.new(
      1,
      0 => YAML,
      1 => JSON,
      2 => MessagePack,
    )
  end

  test "#dump use the current version" do
    assert_equal "#☠1☢\n{\"foo\":42}", @coder.dump({ foo: 42 })
  end

  test "#dump handle binary data" do
    coder = Paquito::CommentPrefixVersion.new(1, 1 => MessagePack)
    expected = { "foo" => 42 }
    assert_equal expected, coder.load(coder.dump(expected))
  end

  test "#load respects the version prefix" do
    assert_equal({ foo: 42 }, @coder.load("#☠0☢\n---\n:foo: 42"))
  end

  test "#load assumes version 0 if the comment prefix is missing" do
    assert_equal({ foo: 42 }, @coder.load("---\n:foo: 42"))

    assert_raises Psych::BadAlias do
      @coder.load("foo:\n<<: *bar")
    end
  end

  test "#load handle empty strings" do
    @coder.load("")
  end

  test "#load raises an error on unknown versions" do
    error = assert_raises(Paquito::UnsupportedCodec) do
      @coder.load("#☠9☢\nblahblah")
    end
    assert_equal "Unsupported packer version 9", error.message
  end
end

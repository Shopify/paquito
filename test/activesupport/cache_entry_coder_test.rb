# frozen_string_literal: true

require "test_helper"

class PaquitoCacheEntryCoderTest < PaquitoTest
  def setup
    @coder = Paquito.chain(
      Paquito::CacheEntryCoder,
      JSON,
    )
    @cache_dir = Dir.mktmpdir
    @store = ActiveSupport::Cache::FileStore.new(@cache_dir, coder: @coder)
  end

  def test_simple_key
    @store.write("foo", "bar")
    assert_equal ["bar"].to_json, raw_cache_read("foo")
  end

  def test_simple_key_with_expriry
    @store.write("foo", "bar", expires_in: 5.minutes)
    value, expiry = JSON.parse(raw_cache_read("foo"))
    assert_equal "bar", value
    assert_instance_of Float, expiry
  end

  def test_simple_key_with_version
    @store.write("foo", "bar", version: "v1")
    value, expiry, version = JSON.parse(raw_cache_read("foo"))
    assert_equal "bar", value
    assert_nil expiry
    assert_equal "v1", version
  end

  private

  def raw_cache_read(key)
    File.read(Dir[File.join(@cache_dir, "**", key)].first)
  end
end

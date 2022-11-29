# frozen_string_literal: true

require "test_helper"

class FlatPaquitoCacheEntryCoderTest < PaquitoTest
  def setup
    @coder = Paquito::FlatCacheEntryCoder.new(JSON)
    @cache_dir = Dir.mktmpdir
    @store = ActiveSupport::Cache::FileStore.new(@cache_dir, coder: @coder)
  end

  def test_simple_key
    @store.write("foo", "bar")
    assert_equal("bar", @store.read("foo"))
    entry = read_entry("foo")
    assert_nil(entry.expires_at)
    assert_nil(entry.version)
  end

  def test_simple_key_with_expriry
    @store.write("foo", "bar", expires_in: 5.minutes)

    assert_equal("bar", @store.read("foo"))
    entry = read_entry("foo")
    assert_in_delta(5.minutes.from_now.to_f, entry.expires_at, 0.5)
    assert_nil(entry.version)
  end

  def test_simple_key_with_version
    @store.write("foo", "bar", version: "v1")

    assert_equal("bar", @store.read("foo"))
    entry = read_entry("foo")
    assert_nil(entry.expires_at)
    assert_equal("v1", entry.version)
  end

  private

  def read_entry(key)
    @store.send(:read_entry, @store.send(:normalize_key, key, {}))
  end

  def raw_cache_read(key)
    File.read(Dir[File.join(@cache_dir, "**", key)].first)
  end
end

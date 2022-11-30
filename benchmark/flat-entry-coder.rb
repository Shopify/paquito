#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "paquito"
require "active_support"
require "benchmark/ips"

CODEC = Paquito::CodecFactory.build
ORIGINAL = Paquito::SingleBytePrefixVersion.new(
  0,
  0 => Paquito.chain(
    Paquito::CacheEntryCoder,
    CODEC,
  ),
)
FLAT = Paquito::FlatCacheEntryCoder.new(
  Paquito::SingleBytePrefixVersionWithStringBypass.new(
    0,
    0 => CODEC,
  )
)

entries = {
  small_string: "Hello World!",
  bytes_1mb: Random.bytes(1_000_000),
  int_array: 1000.times.to_a,
}

entries.each do |name, object|
  entry = ActiveSupport::Cache::Entry.new(object, expires_at: 15.minutes.from_now.to_f)
  original_payload = ORIGINAL.dump(entry).freeze
  flat_payload = FLAT.dump(entry).freeze

  puts " === Read #{name} ==="
  Benchmark.ips do |x|
    x.report("original") { ORIGINAL.load(original_payload) }
    x.report("flat") { FLAT.load(flat_payload) }
    x.compare!(order: :baseline)
  end

  puts " === Write #{name} ==="
  Benchmark.ips do |x|
    x.report("original") { ORIGINAL.dump(entry) }
    x.report("flat") { FLAT.dump(entry) }
    x.compare!(order: :baseline)
  end

  puts
end

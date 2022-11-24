#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "paquito"
require "benchmark/ips"

CODEC = Paquito::CodecFactory.build([])
VERSIONED = Paquito::SingleBytePrefixVersion.new(0, 0 => CODEC)
BYPASS = Paquito::SingleBytePrefixVersionWithStringBypass.new(0, 0 => CODEC)

[100, 10_000, 1_000_000].each do |size|
  string = Random.bytes(size).freeze
  msgpack_payload = VERSIONED.dump(string).freeze
  bypass_payload = BYPASS.dump(string).freeze
  marshal_payload = Marshal.dump(string).freeze

  puts " === Read #{size}B ==="
  Benchmark.ips do |x|
    x.report("marshal") { Marshal.load(marshal_payload) }
    x.report("msgpack") { VERSIONED.load(msgpack_payload) }
    x.report("bypass") { BYPASS.load(bypass_payload) }
    x.compare!(order: :baseline)
  end

  puts " === Write #{size}B ==="
  Benchmark.ips do |x|
    x.report("marshal") { Marshal.dump(string) }
    x.report("msgpack") { VERSIONED.dump(string) }
    x.report("bypass") { BYPASS.dump(string) }
    x.compare!(order: :baseline)
  end

  puts
end

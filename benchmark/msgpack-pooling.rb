#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "paquito"
require "benchmark/ips"

BASELINE = Paquito::CodecFactory.build([Symbol], pool: false)
POOLED = Paquito::CodecFactory.build([Symbol], pool: 1)

PAYLOAD = BASELINE.dump(:foo)
MARSHAL_PAYLOAD = Marshal.dump(:foo)

Benchmark.ips do |x|
  x.report("marshal") { Marshal.load(MARSHAL_PAYLOAD) }
  x.report("msgpack") { BASELINE.load(PAYLOAD) }
  x.report("pooled") { POOLED.load(PAYLOAD) }
  x.compare!(order: :baseline)
end

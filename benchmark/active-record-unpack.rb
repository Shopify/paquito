#!/usr/bin/env ruby
# frozen_string_literal: true

require "bundler/setup"
require "active_record"
require "active_support"
require "paquito"
require "benchmark/ips"

# Set up an in-memory SQLite database with a table that mirrors a typical
# Active Record model — 39 columns with a mix of types and many nils.
ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")

ActiveRecord::Schema.define do
  create_table :records do |t|
    t.string(:string1)
    t.string(:string2)
    t.text(:text1)
    t.string(:string3)
    t.string(:string4)
    t.string(:string5)
    t.string(:string6)
    t.string(:string7)
    t.string(:string8)
    t.boolean(:boolean1)
    t.integer(:integer1)
    t.string(:string9)
    t.string(:string10)
    t.string(:string11)
    t.float(:float1)
    t.float(:float2)
    t.string(:string12)
    t.integer(:integer2)
    t.string(:string13)
    t.string(:string14)
    t.integer(:integer3)
    t.boolean(:boolean2)
    t.boolean(:boolean3)
    t.string(:string15)
    t.string(:string16)
    t.datetime(:datetime1)
    t.string(:string17)
    t.string(:string18)
    t.string(:string19)
    t.boolean(:boolean4)
    t.string(:string20)
    t.datetime(:created_at)
    t.datetime(:updated_at)
    t.string(:string21)
    t.string(:string22)
    t.integer(:integer4)
    t.string(:string23)
    t.integer(:integer5)
  end
end

class Record < ActiveRecord::Base
end

TEXT_BLOB = <<~TEXT
  Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor
  incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis
  nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.
  Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore
  eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt
  in culpa qui officia deserunt mollit anim id est laborum.
TEXT

now = Time.utc(2026, 3, 4, 18, 49, 17)

record = Record.create!(
  string1:   "short1",
  string2:   "medium_string@test",
  text1:     TEXT_BLOB,
  string3:   "medium.string.value",
  string4:   "medium12",
  string5:   "AB",
  string6:   "a medium string!",
  string7:   "ABC 123",
  string8:   "medstr01",
  boolean1:  nil,
  integer1:  360283,
  string9:   nil,
  string10:  "5551234567",
  string11:  nil,
  float1:    nil,
  float2:    nil,
  string12:  "medium.string.value",
  integer2:  1000001,
  string13:  "a_medium_string_val",
  string14:  "another_val",
  integer3:  1,
  boolean2:  false,
  boolean3:  false,
  string15:  "en",
  string16:  "a" * 64,
  datetime1: nil,
  string17:  "a_slightly_longer_string",
  string18:  nil,
  string19:  nil,
  boolean4:  false,
  string20:  nil,
  created_at: now,
  updated_at: now,
  string21:  nil,
  string22:  nil,
  integer4:  1,
  string23:  nil,
  integer5:  1,
)

codec = Paquito::CodecFactory.build([ActiveRecord::Base])

payload = codec.dump(record).freeze

# Sanity check
codec.load(payload).tap do |restored|
  raise "Round-trip failed!" unless restored.attributes == record.attributes
end

stage = ENV.fetch("STAGE", "after")

puts "=== dump ==="
Benchmark.ips do |x|
  x.save!("/tmp/paquito-bench-active-record-dump.json")
  x.report("dump (#{stage})") { codec.dump(record) }
  x.compare!(order: :baseline)
end

puts
puts "=== load ==="
Benchmark.ips do |x|
  x.save!("/tmp/paquito-bench-active-record-load.json")
  x.report("load (#{stage})") { codec.load(payload) }
  x.compare!(order: :baseline)
end

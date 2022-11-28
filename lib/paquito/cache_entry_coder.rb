# frozen_string_literal: true

gem "activesupport", ">= 7.0"

module Paquito
  module CacheEntryCoder
    def self.dump(entry)
      attrs = [entry.value, entry.expires_at, entry.version]
      # drop any trailing nil values to save a couple bytes
      attrs.pop until !attrs.last.nil? || attrs.empty?
      attrs
    end

    def self.load(payload)
      entry = ::ActiveSupport::Cache::Entry.allocate
      value, expires_in, version = payload
      entry.instance_variable_set(:@value, value)
      entry.instance_variable_set(:@expires_in, expires_in)
      entry.instance_variable_set(:@created_at, 0.0)
      entry.instance_variable_set(:@version, version)
      entry
    end
  end
end

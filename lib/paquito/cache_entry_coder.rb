# frozen_string_literal: true

gem "activesupport", ">= 7.0"

module Paquito
  module CacheEntryCoder
    def self.dump(entry)
      entry.pack
    end

    def self.load(payload)
      ::ActiveSupport::Cache::Entry.unpack(payload)
    end
  end
end

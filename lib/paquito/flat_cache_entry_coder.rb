# frozen_string_literal: true

gem "activesupport", ">= 7.0"

module Paquito
  class FlatCacheEntryCoder
    METADATA_CODEC = CodecFactory.build

    def initialize(value_coder)
      @value_coder = value_coder
    end

    def dump(entry)
      parts = entry.pack
      value = parts.shift
      metadata = METADATA_CODEC.dump(parts)
      metadata.bytesize.chr(Encoding::BINARY) << metadata << @value_coder.dump(value)
    end

    def load(payload)
      metadata_size = payload.ord
      parts = METADATA_CODEC.load(payload.byteslice(1, metadata_size))
      value = @value_coder.load(payload.byteslice((metadata_size + 1)..-1))
      parts.unshift(value)
      ::ActiveSupport::Cache::Entry.unpack(parts)
    end
  end
end

# frozen_string_literal: true

gem "activesupport", ">= 7.0"

module Paquito
  class FlatCacheEntryCoder
    METADATA_CODEC = CodecFactory.build

    EXPIRES_AT_FORMAT = "E" # Float double-precision, little-endian byte order (8 bytes)
    VERSION_SIZE_FORMAT = "l<" # 32-bit signed, little-endian byte order (int32_t) (4 bytes)
    PREFIX_FORMAT = -(EXPIRES_AT_FORMAT + VERSION_SIZE_FORMAT)
    VERSION_SIZE_OFFSET = [0.0].pack(EXPIRES_AT_FORMAT).bytesize # should be 8
    VERSION_OFFSET = [0.0, 0].pack(PREFIX_FORMAT).bytesize # Should be 12
    VERSION_SIZE_UNPACK = -"@#{VERSION_SIZE_OFFSET}#{VERSION_SIZE_FORMAT}"

    def initialize(value_coder)
      @value_coder = value_coder
    end

    def dump(entry)
      version = entry.version
      payload = [
        entry.expires_at || 0.0,
        version ? version.bytesize : -1,
      ].pack(PREFIX_FORMAT)
      payload << version if version
      payload << @value_coder.dump(entry.value)
    end

    def load(payload)
      expires_at = payload.unpack1(EXPIRES_AT_FORMAT)
      expires_at = nil if expires_at == 0.0

      version_size = payload.unpack1(VERSION_SIZE_UNPACK)
      if version_size < 0
        version_size = 0
      else
        version = payload.byteslice(VERSION_OFFSET, version_size)
      end

      ::ActiveSupport::Cache::Entry.new(
        @value_coder.load(payload.byteslice((VERSION_OFFSET + version_size)..-1).freeze),
        expires_at: expires_at,
        version: version,
      )
    end
  end
end

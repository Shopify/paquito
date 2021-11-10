# frozen_string_literal: true

module Paquito
  class ConditionalCompressor
    UNCOMPRESSED = 0
    COMPRESSED = 1

    def initialize(compressor, compress_threshold)
      @compressor = Paquito.cast(compressor)
      @compress_threshold = compress_threshold
    end

    def dump(uncompressed)
      uncompressed_size = uncompressed.bytesize
      version = UNCOMPRESSED
      value = uncompressed

      if @compress_threshold && uncompressed_size > @compress_threshold
        compressed = @compressor.dump(uncompressed)
        if compressed.bytesize < uncompressed_size
          version = COMPRESSED
          value = compressed
        end
      end

      version.chr(Encoding::BINARY) << value
    end

    def load(payload)
      payload_version = payload.getbyte(0)
      data = payload.byteslice(1..-1)
      case payload_version
      when UNCOMPRESSED
        data
      when COMPRESSED
        @compressor.load(data)
      else
        raise UnpackError, "invalid ConditionalCompressor version"
      end
    end
  end
end

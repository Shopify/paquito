# frozen_string_literal: true

module Paquito
  class SingleBytePrefixVersion
    def initialize(current_version, coders)
      @current_version = validate_version(current_version)
      @coders = coders.transform_keys { |v| validate_version(v) }.transform_values { |c| Paquito.cast(c) }
      @current_coder = coders.fetch(current_version)
    end

    def dump(object)
      @current_version.chr(Encoding::BINARY) << @current_coder.dump(object)
    end

    def load(payload)
      payload_version = payload.getbyte(0)
      unless payload_version
        raise UnsupportedCodec, "Missing version byte."
      end

      coder = @coders.fetch(payload_version) do
        raise UnsupportedCodec, "Unsupported packer version #{payload_version}"
      end
      coder.load(payload.byteslice(1..-1))
    end

    private

    def validate_version(version)
      unless (0..255).cover?(version)
        raise ArgumentError, "Invalid version #{version.inspect}, versions must be an integer between 0 and 255"
      end

      version
    end
  end
end

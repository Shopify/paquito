# frozen_string_literal: true

module Paquito
  class SingleBytePrefixVersion
    def initialize(current_version, coders)
      @current_version = current_version
      @coders = coders.transform_values { |c| Paquito.cast(c) }
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
  end
end

# frozen_string_literal: true

module Paquito
  class SingleBytePrefixVersionWithStringBypass < SingleBytePrefixVersion
    UTF8_VERSION = 255
    BINARY_VERSION = 254
    ASCII_VERSION = 253

    def initialize(current_version, coders, string_coder = nil)
      super(current_version, coders)
      @string_coder = string_coder
    end

    def dump(object)
      if object.class == String # We don't want to match subclasses
        case object.encoding
        when Encoding::UTF_8
          UTF8_VERSION.chr(Encoding::BINARY) << (@string_coder ? @string_coder.dump(object) : object.b)
        when Encoding::BINARY
          BINARY_VERSION.chr(Encoding::BINARY) << (@string_coder ? @string_coder.dump(object) : object)
        when Encoding::US_ASCII
          ASCII_VERSION.chr(Encoding::BINARY) << (@string_coder ? @string_coder.dump(object) : object)
        else
          super
        end
      else
        super
      end
    end

    def load(payload)
      payload_version = payload.getbyte(0)
      unless payload_version
        raise UnsupportedCodec, "Missing version byte."
      end

      case payload_version
      when UTF8_VERSION
        string = payload.byteslice(1..-1).force_encoding(Encoding::UTF_8)
        @string_coder ? @string_coder.load(string) : string
      when BINARY_VERSION
        string = payload.byteslice(1..-1).force_encoding(Encoding::BINARY)
        @string_coder ? @string_coder.load(string) : string
      when ASCII_VERSION
        string = payload.byteslice(1..-1).force_encoding(Encoding::US_ASCII)
        @string_coder ? @string_coder.load(string) : string
      else
        coder = @coders.fetch(payload_version) do
          raise UnsupportedCodec, "Unsupported packer version #{payload_version}"
        end
        coder.load(payload.byteslice(1..-1))
      end
    end

    private

    def validate_version(version)
      unless (0..252).cover?(version)
        raise ArgumentError, "Invalid version #{version.inspect}, versions must be an integer between 0 and 252"
      end

      version
    end
  end
end

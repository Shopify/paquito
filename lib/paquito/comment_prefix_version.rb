# frozen_string_literal: true

module Paquito
  class CommentPrefixVersion
    PREFIX = "#\u2620"
    SUFFIX = "\u2622\n"
    VERSION_POSITION = PREFIX.bytesize

    HEADER_SLICE = (0..(PREFIX.bytesize + SUFFIX.bytesize))
    PAYLOAD_SLICE = (PREFIX.bytesize + 1 + SUFFIX.bytesize)..-1
    DEFAULT_VERSION = 0

    def initialize(current_version, coders)
      unless (0..9).cover?(current_version) && coders.keys.all? { |version| (0..9).cover?(version) }
        raise ArgumentError, "CommentPrefixVersion versions must be between 0 and 9"
      end

      @current_version = current_version
      @coders = coders.transform_values { |c| Paquito.cast(c) }.freeze
      @current_coder = coders.fetch(current_version)
    end

    def dump(object)
      prefix = +"#{PREFIX}#{@current_version}#{SUFFIX}"
      payload = @current_coder.dump(object)
      if payload.encoding == Encoding::BINARY
        prefix.b << payload
      else
        prefix << payload
      end
    end

    def load(payload)
      payload_version, serial = extract_version(payload)

      coder = @coders.fetch(payload_version) do
        raise UnsupportedCodec, "Unsupported packer version #{payload_version}"
      end
      coder.load(serial)
    end

    private

    def extract_version(serial)
      header = serial.byteslice(HEADER_SLICE)&.force_encoding(Encoding::UTF_8)
      unless header.start_with?(PREFIX) && header.end_with?(SUFFIX)
        return [DEFAULT_VERSION, serial]
      end

      version = header.getbyte(VERSION_POSITION) - 48 # ASCII byte to number
      [version, serial.byteslice(PAYLOAD_SLICE) || ""]
    end
  end
end

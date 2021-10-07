# frozen_string_literal: true

module Paquito
  class Deflater
    def initialize(deflater)
      @deflater = deflater
    end

    def dump(serial)
      @deflater.deflate(serial)
    end

    def load(payload)
      @deflater.inflate(payload)
    end
  end
end

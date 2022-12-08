# frozen_string_literal: true

module Paquito
  class Compressor
    def initialize(compressor)
      @compressor = compressor
    end

    def dump(serial)
      @compressor.compress(serial)
    end

    def load(payload)
      @compressor.decompress(payload)
    end
  end
end

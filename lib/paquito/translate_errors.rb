# frozen_string_literal: true

module Paquito
  class TranslateErrors
    def initialize(coder)
      @coder = coder
    end

    def dump(object)
      @coder.dump(object)
    rescue Paquito::Error
      raise
    rescue => error
      raise PackError, error.message
    end

    def load(payload)
      @coder.load(payload)
    rescue Paquito::Error
      raise
    rescue => error
      raise UnpackError, error.message
    end
  end
end

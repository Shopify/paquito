# frozen_string_literal: true

module Paquito
  class AllowNil
    def initialize(coder)
      @coder = Paquito.cast(coder)
    end

    def dump(object)
      return nil if object.nil?

      @coder.dump(object)
    end

    def load(payload)
      return nil if payload.nil?

      @coder.load(payload)
    end
  end
end

# frozen_string_literal: true

module Paquito
  class CoderChain
    def initialize(*coders)
      @coders = coders.flatten.map { |c| Paquito.cast(c) }
      @reverse_coders = @coders.reverse
    end

    def dump(object)
      payload = object
      @coders.each { |c| payload = c.dump(payload) }
      payload
    end

    def load(payload)
      object = payload
      @reverse_coders.each { |c| object = c.load(object) }
      object
    end
  end
end

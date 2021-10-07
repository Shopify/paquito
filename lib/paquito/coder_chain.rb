# frozen_string_literal: true

module Paquito
  class CoderChain
    def initialize(*coders)
      @coders = coders.flatten.map { |c| Paquito.cast(c) }
    end

    def dump(object)
      payload = object
      @coders.each { |c| payload = c.dump(payload) }
      payload
    end

    def load(payload)
      object = payload
      @coders.reverse_each { |c| object = c.load(object) }
      object
    end
  end
end

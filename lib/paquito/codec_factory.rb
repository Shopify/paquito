# frozen_string_literal: true

require "paquito/types"
require "paquito/coder_chain"

module Paquito
  class CodecFactory
    def self.build(types, freeze: false, serializable_type: false, pool: 1)
      factory = if types.empty? && !serializable_type
        MessagePack::DefaultFactory
      else
        MessagePack::Factory.new
      end

      Types.register(factory, types) unless types.empty?
      Types.register_serializable_type(factory) if serializable_type

      if pool && pool > 0 && factory.respond_to?(:pool)
        factory = factory.freeze.pool(pool, freeze: freeze)
        freeze = false
      end

      MessagePackCodec.new(factory, freeze: freeze)
    end

    class MessagePackCodec
      def initialize(factory, freeze: false)
        @factory = factory
        @freeze = freeze
      end

      def dump(object)
        @factory.dump(object)
      rescue NoMethodError => error
        raise PackError.new(error.message, error.receiver)
      rescue RangeError => error
        raise PackError, "#{error.class.name}, #{error.message}"
      end

      def load(payload)
        if @freeze
          @factory.load(payload, freeze: @freeze)
        else
          @factory.load(payload)
        end
      rescue MessagePack::UnpackError => error
        raise UnpackError, error.message
      rescue IOError => error
        raise UnpackError, "#{error.class.name}, #{error.message}"
      end
    end
  end
end

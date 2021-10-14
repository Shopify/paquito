# frozen_string_literal: true

require "paquito/types"
require "paquito/coder_chain"

module Paquito
  class CodecFactory
    def self.build(types, freeze: false, serializable_type: false)
      factory =
        if types.empty? && !serializable_type
          MessagePack
        else
          MessagePack::Factory.new
        end
      Types.register(factory, types) unless types.empty?
      Types.register_serializable_type(factory) if serializable_type
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
        @factory.load(payload, freeze: @freeze)
      rescue MessagePack::UnpackError => error
        raise UnpackError, error.message
      end
    end
  end
end

# frozen_string_literal: true

require "paquito/errors"
require "paquito/active_record_coder"

module Paquito
  module Types
    class ActiveRecordPacker
      factory = MessagePack::Factory.new
      # These are the types available when packing/unpacking ActiveRecord::Base instances.
      Types.register(factory, [Symbol, Time, DateTime, Date, BigDecimal, ActiveSupport::TimeWithZone])
      FACTORY = factory
      # Raise on any undeclared type
      factory.register_type(
        0x7f,
        Object,
        packer: ->(value) { raise PackError.new("undeclared type", value) },
        unpacker: ->(*) {},
      )

      core_types = [String, Integer, TrueClass, FalseClass, NilClass, Float, Array, Hash]
      ext_types = FACTORY.registered_types.map { |t| t[:class] }
      VALID_CLASSES = core_types + ext_types

      def self.dump(value)
        coded = ActiveRecordCoder.dump(value)
        FACTORY.dump(coded)
      rescue NoMethodError, PackError => e
        raise unless PackError === e || e.name == :to_msgpack

        class_name = value.class.name
        receiver_name = e.receiver.class.name
        error_attrs = coded[1][1].select { |_, attr_value| VALID_CLASSES.exclude?(attr_value.class) }

        Rails.logger.warn(<<~LOG.squish)
          [MessagePackCodecTypes]
          Failed to encode record with ActiveRecordCoder
          class=#{class_name}
          error_class=#{receiver_name}
          error_attrs=#{error_attrs.keys.join(", ")}
        LOG

        raise PackError.new("failed to pack ActiveRecord object", e.receiver)
      end

      def self.load(value)
        ActiveRecordCoder.load(FACTORY.load(value))
      end
    end
  end
end

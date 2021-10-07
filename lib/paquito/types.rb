# frozen_string_literal: true

require "paquito/errors"

module Paquito
  module Types
    autoload :ActiveRecordPacker, "paquito/types/active_record_packer"

    # Do not change those formats, this would break current codecs.
    TIME_FORMAT = "q< L<"
    TIME_WITH_ZONE_FORMAT = "q< L< a*"
    DATE_TIME_FORMAT = "s< C C C C q< L< c C"
    DATE_FORMAT = "s< C C"

    SERIALIZE_METHOD = :as_pack
    SERIALIZE_PROC = SERIALIZE_METHOD.to_proc
    DESERIALIZE_METHOD = :from_pack

    class CustomTypesRegistry
      class << self
        def packer(value)
          packers.fetch(klass = value.class) do
            if packable?(value) && unpackable?(klass)
              @packers[klass] = SERIALIZE_PROC
            end
          end
        end

        def unpacker(klass)
          unpackers.fetch(klass) do
            if unpackable?(klass)
              @unpackers[klass] = klass.method(DESERIALIZE_METHOD).to_proc
            end
          end
        end

        def register(klass, packer: nil, unpacker:)
          if packer
            raise ArgumentError, "packer for #{klass} already defined" if packers.key?(klass)
            packers[klass] = packer
          end

          raise ArgumentError, "unpacker for #{klass} already defined" if unpackers.key?(klass)
          unpackers[klass] = unpacker

          self
        end

        private

        def packable?(value)
          value.class.method_defined?(SERIALIZE_METHOD) ||
            raise(PackError.new("#{value.class} is not serializable", value))
        end

        def unpackable?(klass)
          klass.respond_to?(DESERIALIZE_METHOD) ||
            raise(UnpackError, "#{klass} is not deserializable")
        end

        def packers
          @packers ||= {}
        end

        def unpackers
          @unpackers ||= {}
        end
      end
    end

    # Do not change any #code, this would break current codecs.
    # New types can be added as long as they have unique #code.
    TYPES = {
      "Symbol" => {
        code: 0x00,
        packer: :to_s,
        unpacker: :to_sym,
      }.freeze,
      "Time" => {
        code: 0x01,
        packer: ->(value) do
          rational = value.utc.to_r
          [rational.numerator, rational.denominator].pack(TIME_FORMAT)
        end,
        unpacker: ->(value) do
          numerator, denominator = value.unpack(TIME_FORMAT)
          Time.at(Rational(numerator, denominator)).utc
        end,
      }.freeze,
      "DateTime" => {
        code: 0x02,
        packer: ->(value) do
          sec = value.sec + value.sec_fraction
          offset = value.offset
          [
            value.year,
            value.month,
            value.day,
            value.hour,
            value.minute,
            sec.numerator,
            sec.denominator,
            offset.numerator,
            offset.denominator,
          ].pack(DATE_TIME_FORMAT)
        end,
        unpacker: ->(value) do
          (
            year,
            month,
            day,
            hour,
            minute,
            sec_numerator,
            sec_denominator,
            offset_numerator,
            offset_denominator,
          ) = value.unpack(DATE_TIME_FORMAT)
          DateTime.new( # rubocop:disable Style/DateTime
            year,
            month,
            day,
            hour,
            minute,
            Rational(sec_numerator, sec_denominator),
            Rational(offset_numerator, offset_denominator),
          )
        end,
      }.freeze,
      "Date" => {
        code: 0x03,
        packer: ->(value) do
          [value.year, value.month, value.day].pack(DATE_FORMAT)
        end,
        unpacker: ->(value) do
          year, month, day = value.unpack(DATE_FORMAT)
          Date.new(year, month, day)
        end,
      }.freeze,
      "BigDecimal" => {
        code: 0x04,
        packer: :_dump,
        unpacker: BigDecimal.method(:_load),
      }.freeze,
      # Range => { code: 0x05 }, do not recycle that code
      "ActiveRecord::Base" => {
        code: 0x6,
        packer: ->(value) { ActiveRecordPacker.dump(value) },
        unpacker: ->(value) { ActiveRecordPacker.load(value) },
      }.freeze,
      "ActiveSupport::HashWithIndifferentAccess" => {
        code: 0x7,
        packer: ->(factory, value) do
          unless value.instance_of?(ActiveSupport::HashWithIndifferentAccess)
            raise PackError.new("cannot pack HashWithIndifferentClass subclass", value)
          end
          factory.dump(value.to_h)
        end,
        unpacker: ->(factory, value) { HashWithIndifferentAccess.new(factory.load(value)) },
      },
      "ActiveSupport::TimeWithZone" => {
        code: 0x8,
        packer: ->(value) do
          [
            value.utc.to_i,
            (value.time.sec_fraction * 1_000_000_000).to_i,
            value.time_zone.name,
          ].pack(TIME_WITH_ZONE_FORMAT)
        end,
        unpacker: ->(value) do
          sec, nsec, time_zone_name = value.unpack(TIME_WITH_ZONE_FORMAT)
          time = Time.at(sec, nsec, :nsec, in: 0).utc
          time_zone = ::Time.find_zone(time_zone_name)
          ActiveSupport::TimeWithZone.new(time, time_zone)
        end,
      },
      "Set" => {
        code: 0x9,
        packer: ->(factory, value) { factory.dump(value.to_a) },
        unpacker: ->(factory, value) { factory.load(value).to_set },
      },
      # Object => { code: 0x7f }, reserved for serializable Object type
    }.freeze

    class << self
      def register(factory, types)
        types.each do |type|
          name = type.name

          # Up to Rails 7 ActiveSupport::TimeWithZone#name returns "Time"
          if name == "Time" && defined?(ActiveSupport::TimeWithZone)
            name = "ActiveSupport::TimeWithZone" if type == ActiveSupport::TimeWithZone
          end

          type_attributes = TYPES.fetch(name)
          factory.register_type(
            type_attributes.fetch(:code),
            type,
            packer: curry_callback(type_attributes.fetch(:packer), factory),
            unpacker: curry_callback(type_attributes.fetch(:unpacker), factory),
          )
        end
      end

      def register_serializable_type(factory)
        factory.register_type(
          0x7f,
          Object,
          packer: ->(value) do
            packer = CustomTypesRegistry.packer(value)
            class_name = value.class.to_s
            factory.dump([packer.call(value), class_name])
          end,
          unpacker: ->(value) do
            payload, class_name = factory.load(value)

            begin
              klass = Object.const_get(class_name)
            rescue NameError
              raise ClassMissingError, "missing #{class_name} class"
            end

            unpacker = CustomTypesRegistry.unpacker(klass)
            unpacker.call(payload)
          end
        )
      end

      def define_custom_type(klass, packer: nil, unpacker:)
        CustomTypesRegistry.register(klass, packer: packer, unpacker: unpacker)
      end

      private

      def curry_callback(callback, factory)
        return callback.to_proc if callback.is_a?(Symbol)
        return callback if callback.arity == 1
        callback.curry.call(factory)
      end
    end
  end
end

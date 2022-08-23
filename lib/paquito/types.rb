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
        code: 0,
        packer: Symbol.method_defined?(:name) ? :name.to_proc : :to_s.to_proc,
        unpacker: :to_sym.to_proc,
        optimized_symbols_parsing: true,
      }.freeze,
      "Time" => {
        code: 1,
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
        code: 2,
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
        code: 3,
        packer: ->(value) do
          [value.year, value.month, value.day].pack(DATE_FORMAT)
        end,
        unpacker: ->(value) do
          year, month, day = value.unpack(DATE_FORMAT)
          Date.new(year, month, day)
        end,
      }.freeze,
      "BigDecimal" => {
        code: 4,
        packer: :_dump,
        unpacker: BigDecimal.method(:_load),
      }.freeze,
      # Range => { code: 0x05 }, do not recycle that code
      "ActiveRecord::Base" => {
        code: 6,
        packer: ->(value, packer) { packer.write(ActiveRecordCoder.dump(value)) },
        unpacker: ->(unpacker) { ActiveRecordCoder.load(unpacker.read) },
        recursive: true,
      }.freeze,
      "ActiveSupport::HashWithIndifferentAccess" => {
        code: 7,
        packer: ->(value, packer) do
          unless value.instance_of?(ActiveSupport::HashWithIndifferentAccess)
            raise PackError.new("cannot pack HashWithIndifferentClass subclass", value)
          end

          packer.write(value.to_h)
        end,
        unpacker: ->(unpacker) { ActiveSupport::HashWithIndifferentAccess.new(unpacker.read) },
        recursive: true,
      },
      "ActiveSupport::TimeWithZone" => {
        code: 8,
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
        code: 9,
        packer: ->(value, packer) { packer.write(value.to_a) },
        unpacker: ->(unpacker) { unpacker.read.to_set },
        recursive: true,
      },
      # Integer => { code: 10 }, reserved for oversized Integer
      # Object => { code: 127 }, reserved for serializable Object type
    }
    begin
      require "msgpack/bigint"

      TYPES["Integer"] = {
        code: 10,
        packer: MessagePack::Bigint.method(:to_msgpack_ext),
        unpacker: MessagePack::Bigint.method(:from_msgpack_ext),
        oversized_integer_extension: true,
      }
    rescue LoadError
      # expected on older msgpack
    end

    TYPES.freeze

    class << self
      def register(factory, types)
        types.each do |type|
          # Up to Rails 7 ActiveSupport::TimeWithZone#name returns "Time"
          name = if defined?(ActiveSupport::TimeWithZone) && type == ActiveSupport::TimeWithZone
            "ActiveSupport::TimeWithZone"
          else
            type.name
          end

          type_attributes = TYPES.fetch(name)
          factory.register_type(
            type_attributes.fetch(:code),
            type,
            type_attributes
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
    end
  end
end

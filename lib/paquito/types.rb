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

    MAX_UINT32 = (2**32) - 1
    MAX_INT64 = (2**63) - 1

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
    TYPES = [
      {
        code: 0,
        class: "Symbol",
        version: 0,
        packer: Symbol.method_defined?(:name) ? :name.to_proc : :to_s.to_proc,
        unpacker: :to_sym.to_proc,
        optimized_symbols_parsing: true,
      }.freeze,
      {
        code: 1,
        class: "Time",
        version: 0,
        packer: ->(value) do
          rational = value.to_r
          if rational.numerator > MAX_INT64 || rational.denominator > MAX_UINT32
            raise PackError, "Time instance out of bounds (#{rational.inspect}), see: https://github.com/Shopify/paquito/issues/26"
          end

          [rational.numerator, rational.denominator].pack(TIME_FORMAT)
        end,
        unpacker: ->(value) do
          numerator, denominator = value.unpack(TIME_FORMAT)
          at = begin
            Rational(numerator, denominator)
          rescue ZeroDivisionError
            raise UnpackError, "Corrupted Time object, see: https://github.com/Shopify/paquito/issues/26"
          end
          Time.at(at).utc
        end,
      }.freeze,
      {
        code: 2,
        class: "DateTime",
        version: 0,
        packer: ->(value) do
          sec = value.sec + value.sec_fraction
          offset = value.offset

          if sec.numerator > MAX_INT64 || sec.denominator > MAX_UINT32
            raise PackError, "DateTime#sec_fraction out of bounds (#{sec.inspect}), see: https://github.com/Shopify/paquito/issues/26"
          end

          if offset.numerator > MAX_INT64 || offset.denominator > MAX_UINT32
            raise PackError, "DateTime#offset out of bounds (#{offset.inspect}), see: https://github.com/Shopify/paquito/issues/26"
          end

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

          begin
            ::DateTime.new(
              year,
              month,
              day,
              hour,
              minute,
              Rational(sec_numerator, sec_denominator),
              Rational(offset_numerator, offset_denominator),
            )
          rescue ZeroDivisionError
            raise UnpackError, "Corrupted DateTime object, see: https://github.com/Shopify/paquito/issues/26"
          end
        end,
      }.freeze,
      {
        code: 3,
        class: "Date",
        version: 0,
        packer: ->(value) do
          [value.year, value.month, value.day].pack(DATE_FORMAT)
        end,
        unpacker: ->(value) do
          year, month, day = value.unpack(DATE_FORMAT)
          ::Date.new(year, month, day)
        end,
      }.freeze,
      {
        code: 4,
        class: "BigDecimal",
        version: 0,
        packer: :_dump,
        unpacker: ::BigDecimal.method(:_load),
      }.freeze,
      # { code: 5, class: "Range" }, do not recycle that code
      {
        code: 6,
        class: "ActiveRecord::Base",
        version: 0,
        packer: ->(value) { ActiveRecordPacker.dump(value) },
        unpacker: ->(value) { ActiveRecordPacker.load(value) },
      }.freeze,
      {
        code: 7,
        class: "ActiveSupport::HashWithIndifferentAccess",
        version: 0,
        packer: ->(value, packer) do
          unless value.instance_of?(ActiveSupport::HashWithIndifferentAccess)
            raise PackError.new("cannot pack HashWithIndifferentClass subclass", value)
          end

          packer.write(value.to_h)
        end,
        unpacker: ->(unpacker) { ActiveSupport::HashWithIndifferentAccess.new(unpacker.read) },
        recursive: true,
      }.freeze,
      {
        code: 8,
        class: "ActiveSupport::TimeWithZone",
        version: 0,
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
      }.freeze,
      {
        code: 9,
        class: "Set",
        version: 0,
        packer: ->(value, packer) { packer.write(value.to_a) },
        unpacker: ->(unpacker) { unpacker.read.to_set },
        recursive: true,
      }.freeze,
      # { code: 10, class: "Integer" }, reserved for oversized Integer
      {
        code: 11,
        class: "Time",
        version: 1,
        recursive: true,
        packer: ->(value, packer) do
          packer.write(value.tv_sec)
          packer.write(value.tv_nsec)
          packer.write(value.utc_offset)
        end,
        unpacker: ->(unpacker) do
          ::Time.at(unpacker.read, unpacker.read, :nanosecond, in: unpacker.read)
        end,
      }.freeze,
      {
        code: 12,
        class: "DateTime",
        version: 1,
        recursive: true,
        packer: ->(value, packer) do
          packer.write(value.year)
          packer.write(value.month)
          packer.write(value.day)
          packer.write(value.hour)
          packer.write(value.minute)

          sec = value.sec + value.sec_fraction
          packer.write(sec.numerator)
          packer.write(sec.denominator)

          offset = value.offset
          packer.write(offset.numerator)
          packer.write(offset.denominator)
        end,
        unpacker: ->(unpacker) do
          ::DateTime.new(
            unpacker.read, # year
            unpacker.read, # month
            unpacker.read, # day
            unpacker.read, # hour
            unpacker.read, # minute
            Rational(unpacker.read, unpacker.read), # sec fraction
            Rational(unpacker.read, unpacker.read), # offset fraction
          )
        end,
      }.freeze,
      {
        code: 13,
        class: "ActiveSupport::TimeWithZone",
        version: 1,
        recursive: true,
        packer: ->(value, packer) do
          time = value.utc
          packer.write(time.tv_sec)
          packer.write(time.tv_nsec)
          packer.write(value.time_zone.name)
        end,
        unpacker: ->(unpacker) do
          utc = ::Time.at(unpacker.read, unpacker.read, :nanosecond, in: "UTC")
          time_zone = ::Time.find_zone(unpacker.read)
          ActiveSupport::TimeWithZone.new(utc, time_zone)
        end,
      }.freeze,
      # { code: 127, class: "Object" }, reserved for serializable Object type
    ]
    begin
      require "msgpack/bigint"

      TYPES << {
        code: 10,
        class: "Integer",
        version: 0,
        packer: MessagePack::Bigint.method(:to_msgpack_ext),
        unpacker: MessagePack::Bigint.method(:from_msgpack_ext),
        oversized_integer_extension: true,
      }
    rescue LoadError
      # expected on older msgpack
    end

    TYPES.freeze

    class << self
      def register(factory, types, format_version: Paquito.format_version)
        types.each do |type|
          # Up to Rails 7 ActiveSupport::TimeWithZone#name returns "Time"
          name = if defined?(ActiveSupport::TimeWithZone) && type == ActiveSupport::TimeWithZone
            "ActiveSupport::TimeWithZone"
          else
            type.name
          end

          matching_types = TYPES.select { |t| t[:class] == name }

          # If multiple types are registered for the same class, the last one will be used for
          # packing. So we sort all matching types so that the active one is registered last.
          past_types, future_types = matching_types.partition { |t| t.fetch(:version) <= format_version }
          if past_types.empty?
            raise KeyError, "No type found for #{name.inspect} with format_version=#{format_version}"
          end

          past_types.sort_by! { |t| t.fetch(:version) }
          (future_types + past_types).each do |type_attributes|
            factory.register_type(
              type_attributes.fetch(:code),
              type,
              type_attributes,
            )
          end
        end
      end

      def register_serializable_type(factory)
        factory.register_type(
          127,
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
          end,
        )
      end

      def define_custom_type(klass, packer: nil, unpacker:)
        CustomTypesRegistry.register(klass, packer: packer, unpacker: unpacker)
      end
    end
  end
end

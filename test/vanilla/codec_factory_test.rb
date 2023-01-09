# frozen_string_literal: true

require "test_helper"

module Paquito
  module SharedCodecFactoryTests
    # The difference is in the prefix which contains details about the internal representation (27 vs 9).
    # However both versions can read each others fine, so it's not a problem.
    RUBY_3_0_BIG_DECIMAL = "\xC7\n\x0427:0.123e3".b.freeze
    RUBY_3_1_BIG_DECIMAL = "\xC7\t\x049:0.123e3".b.freeze
    BIG_DECIMAL_PAYLOAD = RUBY_VERSION >= "3.1" ? RUBY_3_1_BIG_DECIMAL : RUBY_3_0_BIG_DECIMAL

    OBJECTS = {
      symbol: :symbol,
      string: "string",
      array: [:a, "b"],
      time: Time.new(2000, 1, 1, 2, 2, 2, "+00:00"),
      datetime: DateTime.new(2000, 1, 1, 4, 5, 6, "UTC"),
      date: Date.new(2000, 1, 1),
      hash: { a: [:a] },
    }.freeze
    V0_PAYLOAD = "\x87\xC7\x06\x00symbol\xC7\x06\x00symbol\xC7\x06\x00string\xA6string\xC7\x05\x00array\x92" \
      "\xD4\x00a\xA1b\xD6\x00time\xC7\f\x01\x1A`m8\x00\x00\x00\x00\x01\x00\x00\x00\xD7\x00datetime\xC7\x14" \
      "\x02\xD0\a\x01\x01\x04\x05\x06\x00\x00\x00\x00\x00\x00\x00\x01\x00\x00\x00\x00\x01\xD6\x00date\xD6" \
      "\x03\xD0\a\x01\x01\xD6\x00hash\x81\xD4\x00a\x91\xD4\x00a".b.freeze

    V1_PAYLOAD = "\x87\xC7\x06\x00symbol\xC7\x06\x00symbol\xC7\x06\x00string\xA6string\xC7\x05\x00array\x92" \
      "\xD4\x00a\xA1b\xD6\x00time\xC7\a\v\xCE8m`\x1A\x00\x00\xD7\x00datetime\xC7\v\f\xCD\a\xD0\x01\x01\x04" \
      "\x05\x06\x01\x00\x01\xD6\x00date\xD6\x03\xD0\a\x01\x01\xD6\x00hash\x81\xD4\x00a\x91\xD4\x00a".b.freeze

    ObjectOne = Struct.new(:foo, :bar) do
      def as_pack
        [foo, bar]
      end

      def self.from_pack(payload)
        new(*payload)
      end
    end

    ObjectTwo = Struct.new(:baz, :qux) do
      def as_pack
        members.zip(values).to_h
      end

      def self.from_pack(payload)
        new(payload[:baz], payload[:qux])
      end
    end

    def self.included(base = nil, &block)
      if base && !block_given?
        base.class_eval(&@included)
      elsif base.nil? && block_given?
        @included = block
      else
        raise "Can't pass both a base and and block"
      end
    end

    included do
      test "correctly encodes Symbol objects" do
        codec = Paquito::CodecFactory.build([Symbol])

        assert_equal("\xC7\x05\x00hello".b, codec.dump(:hello))
        assert_equal(:hello, codec.load(codec.dump(:hello)))
      end

      test "correctly encodes Time objects" do
        codec = Paquito::CodecFactory.build([Time])

        value = Time.at(Rational(1_486_570_508_539_759, 1_000_000)).utc
        encoded_value = codec.dump(value)
        assert_equal("\xC7\f\x01oW\x18+\aH\x05\x00@B\x0F\x00".b, encoded_value)
        recovered_value = codec.load(encoded_value)
        assert_equal(value.nsec, recovered_value.nsec)
        assert_equal(value, recovered_value)
      end

      test "does not mutate Time objects" do
        time = Time.at(1_671_439_400, in: "+12:30")
        time_state = time.inspect
        assert_equal time_state, time.inspect
        @codec.dump(time)
        assert_equal time_state, time.inspect
      end

      test "correctly encodes DateTime objects" do
        codec = Paquito::CodecFactory.build([DateTime])

        value = DateTime.new(2017, 2, 8, 11, 25, 12.571685, "EST")
        encoded_value = codec.dump(value)
        assert_equal("\xC7\x14\x02\xE1\a\x02\b\v\x19\xA1]&\x00\x00\x00\x00\x00@\r\x03\x00\xFB\x18".b, encoded_value)
        assert_equal(value, codec.load(encoded_value))

        now = DateTime.now
        assert_equal(now, codec.load(codec.dump(now)))
      end

      test "correctly encodes Date objects" do
        codec = Paquito::CodecFactory.build([Date])

        value = Date.new(2017, 2, 8)
        encoded_value = codec.dump(value)
        assert_equal("\xD6\x03\xE1\a\x02\b".b, encoded_value)
        recovered_value = codec.load(encoded_value)
        assert_equal(value, recovered_value)
      end
      test "BigDecimal serialization is stable" do
        assert_equal(
          BIG_DECIMAL_PAYLOAD,
          @codec.dump(BigDecimal(123)),
        )

        assert_equal(
          BigDecimal(123),
          @codec.load(RUBY_3_0_BIG_DECIMAL),
        )

        assert_equal(
          BigDecimal(123),
          @codec.load(RUBY_3_1_BIG_DECIMAL),
        )
      end

      test "reject malformed payloads with Paquito::PackError" do
        assert_raises Paquito::UnpackError do
          @codec.load("\x00\x00")
        end
      end

      test "correctly encodes BigDecimal objects" do
        codec = Paquito::CodecFactory.build([BigDecimal])

        value = BigDecimal("123456789123456789.123456789123456789")
        encoded_value = codec.dump(value)
        assert_equal("\xC7,\x0445:0.123456789123456789123456789123456789e18".b, encoded_value)
        recovered_value = codec.load(encoded_value)
        assert_equal(value, recovered_value)
      end

      test "correctly encodes Set objects" do
        codec = Paquito::CodecFactory.build([Set])

        value = Set.new([1, 2, [3, 4, Set.new([5])]])
        encoded_value = codec.dump(value)
        assert_equal "\xC7\n\t\x93\x01\x02\x93\x03\x04\xD5\t\x91\x05".b, encoded_value

        recovered_value = codec.load(encoded_value)
        assert_equal(value, recovered_value)
      end

      test "supports freeze on load" do
        # without extra types
        codec = Paquito::CodecFactory.build([])
        assert_equal(false, codec.load(codec.dump("foo")).frozen?)

        codec = Paquito::CodecFactory.build([], freeze: true)
        assert_equal(true, codec.load(codec.dump("foo")).frozen?)

        # with extra types
        codec = Paquito::CodecFactory.build([BigDecimal])
        assert_equal(false, codec.load(codec.dump("foo")).frozen?)

        codec = Paquito::CodecFactory.build([BigDecimal], freeze: true)
        assert_equal(true, codec.load(codec.dump("foo")).frozen?)
      end

      test "does not enforce strictness of Hash type without serializable_type option" do
        codec = Paquito::CodecFactory.build([])

        type_subclass = Class.new(Hash)
        object = type_subclass.new

        assert_equal Hash, codec.load(codec.dump(object)).class
      end

      test "enforces strictness of Hash type with serializable_type option" do
        codec = Paquito::CodecFactory.build([], serializable_type: true)

        type_subclass = Class.new(Hash)
        object = type_subclass.new

        assert_raises(Paquito::PackError) { codec.dump(object) }
      end

      test "rejects unknown types with Paquito::PackError" do
        codec = Paquito::CodecFactory.build([])
        assert_raises(Paquito::PackError) do
          codec.dump(Time.now)
        end
      end

      test "rejects undeclared types with serializable_type option" do
        codec = Paquito::CodecFactory.build([], serializable_type: true)

        undeclared_type = Class.new(Object) do
          def to_msgpack(_)
          end
        end
        object = undeclared_type.new

        assert_raises(Paquito::PackError) { codec.dump(object) }
      end

      test "serializes any object defining Object#as_pack and Object.from_pack with serializable_type option" do
        codec = Paquito::CodecFactory.build([Symbol], serializable_type: true)

        object = ObjectOne.new(
          "foo",
          { "bar" => ObjectTwo.new("baz", "qux") },
        )
        decoded = codec.load(codec.dump(object))
        assert_equal object, decoded
      end

      test "handles class name changes by raising defined exception" do
        codec = Paquito::CodecFactory.build([Symbol], serializable_type: true)

        klass = ObjectOne
        object = ObjectOne.new("foo", "bar")
        serial = codec.dump(object)

        begin
          SharedCodecFactoryTests.send(:remove_const, :ObjectOne)
          assert_raises(Paquito::ClassMissingError) do
            codec.load(serial)
          end
        ensure
          SharedCodecFactoryTests.const_set(:ObjectOne, klass) unless SharedCodecFactoryTests.const_defined?(:ObjectOne)
        end
      end

      test "MessagePack errors are encapsulated" do
        error = assert_raises(Paquito::PackError) do
          @codec.dump(2**128)
        end
        assert_equal "RangeError, bignum too big to convert into `unsigned long long'", error.message

        payload = @codec.dump("foo")
        error = assert_raises(Paquito::UnpackError) do
          @codec.load(payload.byteslice(0..-2))
        end
        assert_equal "EOFError, end of buffer reached", error.message
      end

      if defined? MessagePack::Bigint
        test "bigint support" do
          @codec = Paquito::CodecFactory.build([Integer])
          bigint = 2**150
          assert_equal bigint, @codec.load(@codec.dump(bigint))
        end
      end

      test "loading of V0 types is stable" do
        assert_equal(OBJECTS, @codec.load(V0_PAYLOAD))
      end

      test "loading of V1 types is stable" do
        assert_equal(OBJECTS, @codec.load(V1_PAYLOAD))
      end
    end
  end

  class CodecFactoryV0Test < PaquitoTest
    include SharedCodecFactoryTests

    def setup
      @codec = Paquito::CodecFactory.build([Symbol, Time, DateTime, Date, BigDecimal], pool: 1, format_version: 0)
    end

    test "issue#26 version 0 Time serializer may break if denominator is too big" do
      time = Time.at(Rational(1, 2**33))

      assert_raises Paquito::PackError do
        @codec.dump(time)
      end

      assert_raises Paquito::UnpackError do
        @codec.load("\xC7\f\x01\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00")
      end
    end

    test "dumping of V0 types is stable" do
      assert_equal(V0_PAYLOAD, @codec.dump(OBJECTS))
    end
  end

  class CodecFactoryV1Test < PaquitoTest
    include SharedCodecFactoryTests

    def setup
      @codec = Paquito::CodecFactory.build([Symbol, Time, DateTime, Date, BigDecimal], pool: 1, format_version: 1)
    end

    test "preserve Time#zone" do
      with_env("TZ", "EST") do
        now = Time.now
        assert_equal "EST", now.zone
        time_state = now.inspect
        time_copy = @codec.load(@codec.dump(now))
        assert_equal time_state, time_copy.inspect

        skip("Time#zone can't be restored https://bugs.ruby-lang.org/issues/19253")
        assert_equal "EST", time_copy.zone
      end
    end

    test "dumping of V1 types is stable" do
      assert_equal(V1_PAYLOAD, @codec.dump(OBJECTS))
    end
  end
end

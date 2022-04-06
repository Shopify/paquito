# frozen_string_literal: true

require "test_helper"

class PaquitoCodecFactoryTest < PaquitoTest
  def setup
    @codec = Paquito::CodecFactory.build([Symbol, Time, DateTime, Date, BigDecimal])
  end

  test "all types are stable together" do
    assert_equal(
      "\x88\xC7\x06\x00symbol\xC7\x06\x00symbol\xC7\x06\x00string\xA6string\xC7\x05\x00array\x92\xD4\x00a\xA1b" \
      "\xD6\x00time\xC7\f\x01\xCA\x19m8\x00\x00\x00\x00\x01\x00\x00\x00\xD7\x00datetime\xC7\f\x01\xA26m8\x00\x00" \
      "\x00\x00\x01\x00\x00\x00\xD6\x00date\xD6\x03\xD0\a\x01\x01\xD6\x00hash\x81\xD4\x00a\x91\xD4\x00a\xD6\x00hwia\x81\xA3foo\xA3bar".b,
      @codec.dump(
        symbol: :symbol,
        string: "string",
        array: [:a, "b"],
        time: Time.new(2000, 1, 1, 2, 2, 2, "+05:00").utc,
        datetime: DateTime.new(2000, 1, 1, 4, 5, 6, "+05:00").utc, # rubocop:disable Style/DateTime
        date: Date.new(2000, 1, 1),
        hash: { a: [:a] },
        hwia: ActiveSupport::HashWithIndifferentAccess.new("foo" => "bar"),
      )
    )
  end

  test "payloads are forward compatible" do
    expected = {
      symbol: :symbol,
      string: "string",
      array: [:a, "b"],
      time: Time.new(2000, 1, 1, 2, 2, 2, "+05:00").utc,
      datetime: DateTime.new(2000, 1, 1, 4, 5, 6, "+05:00").utc, # rubocop:disable Style/DateTime
      date: Date.new(2000, 1, 1),
      bigdecimal: BigDecimal(123),
      hash: { a: [:a] },
      hwia: ActiveSupport::HashWithIndifferentAccess.new("foo" => "bar"),
    }

    assert_equal(expected, @codec.load(
      "\x89\xC7\x06\x00symbol\xC7\x06\x00symbol\xC7\x06\x00string\xA6string\xC7\x05\x00array\x92\xD4\x00a\xA1b" \
      "\xD6\x00time\xC7\f\x01\xCA\x19m8\x00\x00\x00\x00\x01\x00\x00\x00\xD7\x00datetime\xC7\f\x01\xA26m8\x00\x00" \
      "\x00\x00\x01\x00\x00\x00\xD6\x00date\xD6\x03\xD0\a\x01\x01\xC7\n\x00bigdecimal\xC7\n\x0427:0.123e3\xD6\x00" \
      "hash\x81\xD4\x00a\x91\xD4\x00a\xD6\x00hwia\x81\xA3foo\xA3bar".b,
    ))
  end

  test "correctly supports ActiveSupport::HashWithIndifferentAccess objects" do
    codec = Paquito::CodecFactory.build([ActiveSupport::HashWithIndifferentAccess])

    hash = { 1 => ActiveSupport::HashWithIndifferentAccess.new("foo" => "bar") }

    decoded_hash = codec.load(codec.dump(hash))

    assert_equal Hash, decoded_hash.class
    assert_equal ActiveSupport::HashWithIndifferentAccess, decoded_hash[1].class
    assert_equal hash, decoded_hash
    assert_equal "bar", decoded_hash[1][:foo]
  end

  test "does not support ActiveSupport::HashWithIndifferentAccess subclasses" do
    codec = Paquito::CodecFactory.build([ActiveSupport::HashWithIndifferentAccess])

    hwia_subclass = Class.new(ActiveSupport::HashWithIndifferentAccess)
    object = hwia_subclass.new

    assert_raises(Paquito::PackError) { codec.dump(object) }
  end

  test "correctly encodes ActiveSupport::TimeWithZone objects" do
    codec = Paquito::CodecFactory.build([ActiveSupport::TimeWithZone])

    utc_time = Time.utc(2000, 1, 1, 0, 0, 0, 0.5)
    time_zone = ActiveSupport::TimeZone["Japan"]

    with_env("TZ", "America/Los_Angeles") do
      value = ActiveSupport::TimeWithZone.new(utc_time, time_zone)

      encoded_value = codec.dump(value)
      assert_equal("\xC7\x11\b\x80Cm8\x00\x00\x00\x00\xF4\x01\x00\x00Japan".b, encoded_value)

      decoded_value = codec.load(encoded_value)

      assert_instance_of(ActiveSupport::TimeWithZone, decoded_value)
      assert_equal(utc_time, decoded_value.utc)
      assert_equal("JST", decoded_value.zone)
      assert_equal(500, decoded_value.nsec)
      assert_instance_of(Time, decoded_value.utc)
      assert_equal(value, decoded_value)
    end
  end
end

# frozen_string_literal: true

require "test_helper"

module Paquito
  module ActiveSupportSharedCodecFactoryTests
    OBJECTS = {
      hwia: ActiveSupport::HashWithIndifferentAccess.new("foo" => "bar"),
      time_with_zone: ActiveSupport::TimeWithZone.new(
        Time.new(2000, 1, 1, 2, 2, 2, "UTC"),
        ActiveSupport::TimeZone["Japan"],
      ),
    }
    TYPES = [Symbol, ActiveSupport::HashWithIndifferentAccess, ActiveSupport::TimeWithZone].freeze
    V0_PAYLOAD = "\x82\xD6\x00hwia\xC7\t\a\x81\xA3foo\xA3bar\xC7\x0E\x00" \
      "time_with_zone\xC7\x11\b\x1A`m8\x00\x00\x00\x00\x00\x00\x00\x00Japan".b.freeze
    V1_PAYLOAD = "\x82\xD6\x00hwia\xC7\t\a\x81\xA3foo\xA3bar\xC7\x0E\x00" \
      "time_with_zone\xC7\f\r\xCE8m`\x1A\x00\xA5Japan".b.freeze

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
      test "correctly supports ActiveSupport::HashWithIndifferentAccess objects" do
        hash = { 1 => ActiveSupport::HashWithIndifferentAccess.new("foo" => "bar") }

        decoded_hash = @codec.load(@codec.dump(hash))

        assert_equal Hash, decoded_hash.class
        assert_equal ActiveSupport::HashWithIndifferentAccess, decoded_hash[1].class
        assert_equal hash, decoded_hash
        assert_equal "bar", decoded_hash[1][:foo]
      end

      test "does not support ActiveSupport::HashWithIndifferentAccess subclasses" do
        hwia_subclass = Class.new(ActiveSupport::HashWithIndifferentAccess)
        object = hwia_subclass.new

        assert_raises(Paquito::PackError) { @codec.dump(object) }
      end

      test "loading of V0 types is stable" do
        assert_equal(OBJECTS, @codec.load(V0_PAYLOAD))
      end

      test "loading of V1 types is stable" do
        assert_equal(OBJECTS, @codec.load(V1_PAYLOAD))
      end
    end
  end

  class ActiveSupportCodecFactoryV0Test < PaquitoTest
    include ActiveSupportSharedCodecFactoryTests

    def setup
      @codec = Paquito::CodecFactory.build(TYPES, format_version: 0)
    end

    test "dumping of V0 types is stable" do
      assert_equal(V0_PAYLOAD, @codec.dump(OBJECTS))
    end

    test "correctly encodes ActiveSupport::TimeWithZone objects" do
      utc_time = Time.utc(2000, 1, 1, 0, 0, 0, 0.5)
      time_zone = ActiveSupport::TimeZone["Japan"]

      with_env("TZ", "America/Los_Angeles") do
        value = ActiveSupport::TimeWithZone.new(utc_time, time_zone)

        encoded_value = @codec.dump(value)
        assert_equal("\xC7\x11\b\x80Cm8\x00\x00\x00\x00\xF4\x01\x00\x00Japan".b, encoded_value)

        decoded_value = @codec.load(encoded_value)

        assert_instance_of(ActiveSupport::TimeWithZone, decoded_value)
        assert_equal(utc_time, decoded_value.utc)
        assert_equal("JST", decoded_value.zone)
        assert_equal(500, decoded_value.nsec)
        assert_instance_of(Time, decoded_value.utc)
        assert_equal(value, decoded_value)
      end
    end
  end

  class ActiveSupportCodecFactoryV1Test < PaquitoTest
    include ActiveSupportSharedCodecFactoryTests

    def setup
      @codec = Paquito::CodecFactory.build(TYPES, format_version: 1)
    end

    test "dumping of V1 types is stable" do
      assert_equal(V1_PAYLOAD, @codec.dump(OBJECTS))
    end

    test "correctly encodes ActiveSupport::TimeWithZone objects" do
      utc_time = Time.utc(2000, 1, 1, 0, 0, 0, 0.5)
      time_zone = ActiveSupport::TimeZone["Japan"]

      with_env("TZ", "America/Los_Angeles") do
        value = ActiveSupport::TimeWithZone.new(utc_time, time_zone)

        encoded_value = @codec.dump(value)
        assert_equal("\xC7\x0E\r\xCE8mC\x80\xCD\x01\xF4\xA5Japan".b, encoded_value)

        decoded_value = @codec.load(encoded_value)

        assert_instance_of(ActiveSupport::TimeWithZone, decoded_value)
        assert_equal(utc_time, decoded_value.utc)
        assert_equal("JST", decoded_value.zone)
        assert_equal(500, decoded_value.nsec)
        assert_instance_of(Time, decoded_value.utc)
        assert_equal(value, decoded_value)
      end
    end
  end
end

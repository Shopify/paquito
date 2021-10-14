# frozen_string_literal: true

require "test_helper"

class PaquitoSerializedColumnTest < PaquitoTest
  def setup
    @settings = { currency: "€" }.freeze
    @model = Shop.create!(name: "Test", settings: @settings)
  end

  test "deserialize the payload" do
    assert_equal "#\xE2\x98\xA01\xE2\x98\xA2\n\x81\xD7\x00currency\xA3\xE2\x82\xAC".b, @model.settings_before_type_cast
    assert_equal(@settings, @model.settings)
  end

  test "serialize default values as `nil`" do
    @model.update!(settings: {})
    assert_nil @model.settings_before_type_cast
  end

  test "initialize with the default values" do
    @model.update_column(:settings, nil)
    @model.reload
    assert_equal({}, @model.settings)
  end

  test "raises when trying to serialize a different type" do
    error = assert_raises(ActiveRecord::SerializationTypeMismatch) do
      @model.update(settings: [])
    end
    assert_equal "settings was supposed to be a Hash, but was a Array. -- []", error.message
  end

  class ClassWithRequiredArguments
    def initialize(foo)
    end
  end
  test "enforce 0 arity on the type constructor" do
    error = assert_raises(ArgumentError) do
      Paquito::SerializedColumn.new(JSON, ClassWithRequiredArguments)
    end
    assert_equal(
      "Cannot serialize PaquitoSerializedColumnTest::ClassWithRequiredArguments. " \
        "Classes passed to `serialize` must have a 0 argument constructor.",
      error.message,
    )
  end
end

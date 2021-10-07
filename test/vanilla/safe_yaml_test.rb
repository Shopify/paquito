# frozen_string_literal: true

require "test_helper"

class SafeYAMLTest < PaquitoTest
  def setup
    @coder = Paquito::SafeYAML.new(
      permitted_classes: ["Hash", "Set"],
      deprecated_classes: ["BigDecimal"],
      aliases: true,
    )
  end

  test "#load accepts deprecated classes" do
    expected = BigDecimal("12.34")
    assert_equal expected, @coder.load(YAML.dump(expected))
  end

  test "#load accepts permitted classes" do
    expected = Set[1, 2]
    assert_equal expected, @coder.load(YAML.dump(expected))
  end

  test "#load translate errors" do
    error = assert_raises(Paquito::UnsupportedType) do
      @coder.load(YAML.dump(Time.new))
    end
    assert_equal "Tried to load unspecified class: Time", error.message

    error = assert_raises(Paquito::UnpackError) do
      @coder.load("<<: *foo")
    end
    assert_equal "Unknown alias: foo", error.message

    assert_raises Paquito::UnpackError do
      @coder.load("*>>")
    end
  end

  test "#dump rejects deprecated classes" do
    error = assert_raises(Paquito::UnsupportedType) do
      @coder.dump(BigDecimal("12.34"))
    end
    assert_equal 'Tried to dump unspecified class: "BigDecimal"', error.message
  end

  test "#dump rejects permitted classes" do
    expected = Set[1, 2]
    assert_equal expected, @coder.load(@coder.dump(expected))
  end
end

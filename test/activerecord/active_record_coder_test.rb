# frozen_string_literal: true

require "test_helper"

class PaquitoActiveRecordCodecTest < PaquitoTest
  def setup
    @codec = Paquito::ActiveRecordCoder
  end

  test "correctly encodes AR object with no associations" do
    shop = Shop.find_by!(name: "Snow Devil")

    encoded_value = @codec.dump(shop)
    recovered_value = @codec.load(encoded_value)
    assert_equal(shop, recovered_value)
  end

  test "correctly encodes AR object with associations" do
    shop = Shop.preload(:products, :domain, :owner, :current_features).find_by!(name: "Snow Devil")

    assert_equal(true, shop.association(:products).loaded?)              # has_many
    assert_equal(true, shop.association(:current_features).loaded?)      # has_many through
    assert_equal(true, shop.association(:owner).loaded?)                 # belongs_to
    assert_equal(true, shop.association(:domain).loaded?)                # has_one

    encoded_value = @codec.dump(shop)
    recovered_value = @codec.load(encoded_value)

    assert_equal(true, recovered_value.association(:products).loaded?)              # has_many
    assert_equal(true, recovered_value.association(:current_features).loaded?)      # has_many through
    assert_equal(true, recovered_value.association(:owner).loaded?)                 # belongs_to
    assert_equal(true, recovered_value.association(:domain).loaded?)                # has_one

    refute_empty shop.products
    assert_equal shop.products.first, recovered_value.products.first
  end

  test "format is stable across payload commits" do
    shop = Shop.preload(:products).find_by!(name: "Snow Devil")

    recovered_shop = @codec.load(@codec.dump(shop))

    recovered_shop.save
    assert_equal(shop, recovered_shop)
    assert_equal(shop.products, recovered_shop.products)
  end

  test "raises ClassMissingError if class is not defined" do
    serial = [0, ["Foo", {}]]

    codec = @codec
    error = assert_raises(Paquito::ActiveRecordCoder::ClassMissingError) do
      codec.load(serial)
    end
    assert_equal "undefined class: Foo", error.message
  end

  test "raises AssociationMissingError if association is undefined" do
    serial = [
      [0, [[:foo, [[1, [[:shop, 0]]]]]]],
      ["Shop", {}],
      ["Product", {}],
    ]

    codec = @codec
    error = assert_raises(Paquito::ActiveRecordCoder::AssociationMissingError) do
      codec.load(serial)
    end
    assert_equal "undefined association: foo", error.message
  end
end

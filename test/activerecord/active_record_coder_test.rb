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

  test "encodes wether the record was persisted or not" do
    shop = Shop.find_by!(name: "Snow Devil")
    assert_predicate shop, :persisted?
    recovered_shop = @codec.load(@codec.dump(shop))
    assert_predicate recovered_shop, :persisted?

    new_shop = @codec.load([0, ["Shop", {}, true]])
    refute_predicate new_shop, :persisted?

    recovered_shop = @codec.load(@codec.dump(new_shop))
    refute_predicate recovered_shop, :persisted?
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

  test "raises ColumnsDigestMismatch if columns hash digest does not match" do
    shop = Shop.find_by!(name: "Snow Devil")

    hash_data = "id:INTEGER,name:varchar,settings:BLOB,owner_id:INTEGER"
    correct_hash = ::Digest::MD5.digest(hash_data).unpack1("s")
    serial = [
      [0],
      ["Shop", shop.attributes_for_database, false, correct_hash],
    ]

    assert_equal(shop, @codec.load(serial))

    incorrect_hash = 10
    serial = [
      [0],
      ["Shop", shop.attributes_for_database, false, incorrect_hash],
    ]
    error = assert_raises(Paquito::ActiveRecordCoder::ColumnsDigestMismatch) do
      @codec.load(serial)
    end
    assert_equal(
      "\"#{incorrect_hash}\" does not match the expected digest of \"#{correct_hash}\"",
      error.message,
    )
  end

  test "works with json column with symbol keys assigned" do
    extension = Extension.new(executable: { a: "b" })
    codec_reloaded = @codec.load(@codec.dump(extension))

    assert_equal({ "a" => "b" }, codec_reloaded.attributes["executable"])
  end
end

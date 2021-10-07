# frozen_string_literal: true

require "test_helper"

class PaquitoCodecFactoryActiveRecordTest < PaquitoTest
  test "MessagePack factory correctly encodes AR::Base objects" do
    shop = Shop.preload(:products, :domain).first

    codec = Paquito::CodecFactory.build([ActiveRecord::Base])

    assert_equal(true, shop.association(:products).loaded?)
    assert_equal(true, shop.association(:domain).loaded?)

    encoded_value = codec.dump(shop)
    recovered_value = codec.load(encoded_value)

    assert_equal(true, recovered_value.association(:products).loaded?)
    assert_equal(true, recovered_value.association(:domain).loaded?)

    shop.save

    reencoded_value = codec.dump(shop)
    assert_equal(shop, codec.load(reencoded_value))
  end

  test "MessagePack factory handle binary columns in AR::Base objects" do
    model = Shop.first
    assert_instance_of ::ActiveModel::Type::Binary::Data, model.attributes_for_database.fetch("settings")

    payload = Paquito::ActiveRecordCoder.dump(model)
    assert_equal model, Paquito::ActiveRecordCoder.load(payload)

    raw_attributes = payload.dig(1, 1)
    assert_instance_of String, raw_attributes["settings"]

    codec = Paquito::CodecFactory.build([ActiveRecord::Base])
    reloaded_model = codec.load(codec.dump(model))

    assert_equal model.settings, reloaded_model.settings
    assert_equal model.settings_before_type_cast, reloaded_model.settings_before_type_cast
  end
end

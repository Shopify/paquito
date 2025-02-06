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

  test "MessagePack factory supports legacy encoding scheme without columns hash" do
    shop = Shop.preload(:products, :domain).first

    payload_without_columns_hash = "\xC8\x01\x1A\x06\x95\x92\x00\x92\x92\xC7\x06\x00domain\x92\x01\x91\x92\xD6\x00"\
      "shop\x00\x92\xD7\x00products\x92\x92\x02\x91\x92\xD6\x00shop\x00\x92\x03\x91\x92\xD6\x00"\
      "shop\x00\x92\xA4Shop\x84\xA2id\x01\xA4name\xAASnow Devil\xA8settings\xC4\x18#\xE2\x98\xA0"\
      "1\xE2\x98\xA2\n\x81\xD7\x00currency\xA3\xE2\x82\xAC\xA8owner_id\xC0\x92\xA6Domain\x83\xA7"\
      "shop_id\x01\xA2id\x01\xA4name\xABexample.com\x92\xA7Product\x84\xA7shop_id\x01\xA2id\x01\xA4"\
      "name\xAFCheap Snowboard\xA8quantity\x18\x92\xA7Product\x84\xA7shop_id\x01\xA2id\x02\xA4name"\
      "\xB3Expensive Snowboard\xA8quantity\x02".b

    codec = Paquito::CodecFactory.build([ActiveRecord::Base])
    recovered_value = codec.load(payload_without_columns_hash)

    assert_equal(shop, recovered_value)

    assert_equal(true, recovered_value.association(:products).loaded?)
    assert_equal(true, recovered_value.association(:domain).loaded?)

    encoded_value = codec.dump(shop)

    assert_equal(shop, codec.load(encoded_value))

    payload_with_columns_hash = "\xC8\x01\x1E\x06\x95\x92\x00\x92\x92\xC7\x06\x00domain\x92\x01\x91\x92\xD6\x00"\
      "shop\x00\x92\xD7\x00products\x92\x92\x02\x91\x92\xD6\x00shop\x00\x92\x03\x91\x92\xD6\x00shop\x00"\
      "\x93\xA4Shop\x84\xA2id\x01\xA4name\xAASnow Devil\xA8settings\xC4\x18#\xE2\x98\xA01\xE2\x98\xA2"\
      "\n\x81\xD7\x00currency\xA3\xE2\x82\xAC\xA8owner_id\xC0\xC2\x93\xA6Domain\x83\xA7shop_id\x01\xA2id"\
      "\x01\xA4name\xABexample.com\xC2\x93\xA7Product\x84\xA7shop_id\x01\xA2id\x01\xA4name\xAFCheap Snowboard"\
      "\xA8quantity\x18\xC2\x93\xA7Product\x84\xA7shop_id\x01\xA2id\x02\xA4name\xB3Expensive Snowboard\xA8"\
      "quantity\x02\xC2".b

    assert_equal(payload_with_columns_hash, encoded_value)
  end

  test "MessagePack factory handles serialized records with more elements" do
    shop = Shop.preload(:products, :domain).first

    payload = "\xC8\x01*\x06\x95\x92\x00\x92\x92\xC7\x06\x00domain\x92\x01\x91\x92\xD6\x00shop"\
      "\x00\x92\xD7\x00products\x92\x92\x02\x91\x92\xD6\x00shop\x00\x92\x03\x91\x92\xD6\x00shop\x00\x94\xA4Shop"\
      "\x84\xA2id\x01\xA4name\xAASnow Devil\xA8settings\xC4\x18#\xE2\x98\xA01\xE2\x98\xA2\n\x81\xD7\x00currency\xA3"\
      "\xE2\x82\xAC\xA8owner_id\xC0\xC2\xCD>\xAD\x94\xA6Domain\x83\xA7shop_id\x01\xA2id\x01\xA4name\xABexample.com"\
      "\xC2\xCD\x14\x16\x94\xA7Product\x84\xA7shop_id\x01\xA2id\x01\xA4name\xAFCheap Snowboard\xA8quantity\x18\xC2"\
      "\xD1\x9DF\x94\xA7Product\x84\xA7shop_id\x01\xA2id\x02\xA4name\xB3Expensive Snowboard\xA8quantity\x02\xC2\xD1"\
      "\x9DF".b

    codec = Paquito::CodecFactory.build([ActiveRecord::Base])
    recovered_value = codec.load(payload)

    assert_equal(shop, recovered_value)
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

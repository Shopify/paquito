# frozen_string_literal: true

require "test_helper"

class PaquitoCodecFactoryTest < PaquitoTest
  test "correctly encodes ActiveRecord::Base objects" do
    codec = Paquito::CodecFactory.build([ActiveRecord::Base])

    value = Shop.new
    decoded_value = codec.load(codec.dump(value))

    assert_equal value.attributes, decoded_value.attributes
  end
end

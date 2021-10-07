# frozen_string_literal: true

require "test_helper"

class AllowNilTest < PaquitoTest
  def setup
    @coder = Paquito.allow_nil(Marshal)
  end

  test "#load returns nil if passed nil" do
    assert_nil @coder.load(nil)
  end

  test "#dump returns nil if passed nil" do
    assert_nil @coder.dump(nil)
  end
end

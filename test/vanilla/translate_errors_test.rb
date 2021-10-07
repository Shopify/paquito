# frozen_string_literal: true

require "test_helper"

class TranslateErrorsTest < PaquitoTest
  def setup
    @coder = Paquito::TranslateErrors.new(Marshal)
  end

  test "#load translate any error to Paquito::UnpackError" do
    assert_raises Paquito::UnpackError do
      @coder.load("\x00")
    end
  end

  test "#dump translate any error to Paquito::PackError" do
    assert_raises Paquito::PackError do
      @coder.dump(-> {})
    end
  end
end

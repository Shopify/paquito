# frozen_string_literal: true

module Paquito
  Error = Class.new(StandardError)

  class PackError < Error
    attr_reader :receiver

    def initialize(msg, receiver = nil)
      super(msg)
      @receiver = receiver
    end
  end

  UnpackError = Class.new(Error)
  ClassMissingError = Class.new(Error)
  UnsupportedType = Class.new(Error)
  UnsupportedCodec = Class.new(Error)
  VersionMismatchError = Class.new(Error)
end

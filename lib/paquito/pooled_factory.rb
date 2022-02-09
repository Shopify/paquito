# frozen_string_literal: true

module Paquito
  class PooledFactory
    class AbstractPool
      attr_reader :size

      def initialize(size, &block)
        @size = size
        @new_member = block
        @members = []
      end

      def clear
        @members.clear
      end

      def size=(size)
        @size = size
        @members.slice!(size..-1)
      end

      def checkout
        @members.pop || @new_member.call
      end

      def checkin(member)
        if member && @members.size < @size
          reset(member)
          @members << member
        end
      end

      private

      def reset(member)
        raise NotImplementedError, "#reset(member) must be implemented"
      end
    end

    class PackerPool < AbstractPool
      private

      def reset(packer)
        packer.clear
      end
    end

    class UnpackerPool < AbstractPool
      private

      def reset(unpacker)
        unpacker.reset
      end
    end

    def initialize(factory, size, freeze: false)
      @factory = factory
      @packers = PackerPool.new(size) { factory.packer }
      @unpackers = UnpackerPool.new(size) { factory.unpacker(freeze: freeze) }
    end

    def register_type(...)
      ret = @factory.register_type(...)
      @packers.clear
      @unpackers.clear
      ret
    end

    def size
      @packers.size
    end

    def size=(size)
      @packers.size = @unpackers.size = size
    end

    def load(payload, freeze: false)
      unpacker = @unpackers.checkout
      begin
        unpacker.feed_reference(payload)
        unpacker.full_unpack
      ensure
        @unpackers.checkin(unpacker)
      end
    end

    def dump(object)
      packer = @packers.checkout
      begin
        packer.write(object)
        packer.full_pack
      ensure
        @packers.checkin(packer)
      end
    end
  end
end

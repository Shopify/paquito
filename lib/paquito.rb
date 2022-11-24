# frozen_string_literal: true

require "digest/md5"
require "bigdecimal"
require "date"
require "set"
require "yaml"

require "msgpack"

require "paquito/version"
require "paquito/deflater"
require "paquito/allow_nil"
require "paquito/translate_errors"
require "paquito/safe_yaml"
require "paquito/conditional_compressor"
require "paquito/cache_entry_coder"
require "paquito/single_byte_prefix_version"
require "paquito/single_byte_prefix_version_with_string_bypass"
require "paquito/comment_prefix_version"
require "paquito/types"
require "paquito/codec_factory"
require "paquito/struct"
require "paquito/typed_struct"
require "paquito/serialized_column"

module Paquito
  autoload :ActiveRecordCoder, "paquito/active_record_coder"

  class << self
    def cast(coder)
      if coder.respond_to?(:load) && coder.respond_to?(:dump)
        coder
      elsif coder.respond_to?(:deflate) && coder.respond_to?(:inflate)
        Deflater.new(coder)
      else
        raise TypeError, "Coders must respond to #dump and #load, #{coder.inspect} doesn't"
      end
    end

    def chain(*coders)
      CoderChain.new(*coders)
    end

    def allow_nil(coder)
      AllowNil.new(coder)
    end
  end
end

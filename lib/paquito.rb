# frozen_string_literal: true

require "digest/md5"
require "bigdecimal"
require "date"
require "set"
require "yaml"

require "msgpack"

require "paquito/version"
require "paquito/deflater"
require "paquito/compressor"
require "paquito/allow_nil"
require "paquito/translate_errors"
require "paquito/safe_yaml"
require "paquito/conditional_compressor"
require "paquito/single_byte_prefix_version"
require "paquito/single_byte_prefix_version_with_string_bypass"
require "paquito/comment_prefix_version"
require "paquito/types"
require "paquito/codec_factory"
require "paquito/struct"
require "paquito/typed_struct"
require "paquito/serialized_column"

module Paquito
  autoload :CacheEntryCoder, "paquito/cache_entry_coder"
  autoload :FlatCacheEntryCoder, "paquito/flat_cache_entry_coder"
  autoload :ActiveRecordCoder, "paquito/active_record_coder"

  DEFAULT_FORMAT_VERSION = 0
  @format_version = DEFAULT_FORMAT_VERSION

  class << self
    attr_accessor :format_version

    def cast(coder)
      if coder.respond_to?(:load) && coder.respond_to?(:dump)
        coder
      elsif coder.respond_to?(:deflate) && coder.respond_to?(:inflate)
        Deflater.new(coder)
      elsif coder.respond_to?(:compress) && coder.respond_to?(:decompress)
        Compressor.new(coder)
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

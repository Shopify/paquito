# frozen_string_literal: true

# Load Sorbet runtime early so that all conditional requires
# from this gem are loaded properly below
require "sorbet-runtime"
require "zlib"
require "json"
require "yaml"
require "bigdecimal"

$LOAD_PATH.unshift(File.expand_path("../lib", __dir__))
require "paquito"

require "minitest/autorun"

class PaquitoTest < Minitest::Test
  class << self # Stolen from Active Support
    def test(name, &block)
      test_name = "test_#{name.gsub(/\s+/, "_")}".to_sym
      defined = method_defined?(test_name)
      raise "#{test_name} is already defined in #{self}" if defined

      if block_given?
        define_method(test_name, &block)
      else
        define_method(test_name) do
          flunk("No implementation provided for #{name}")
        end
      end
    end
  end

  private

  def with_env(key, value)
    old_env_id = ENV[key]

    if value.nil?
      ENV.delete(key)
    else
      ENV[key] = value.to_s
    end

    yield
  ensure
    ENV[key] = old_env_id
  end

  def update_env(other)
    original = ENV.to_h
    ENV.update(other)
    yield
  ensure
    ENV.replace(original)
  end
end

Dir[File.expand_path("support/*.rb", __dir__)].sort.each do |support|
  require support
end

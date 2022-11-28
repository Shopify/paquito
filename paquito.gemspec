# frozen_string_literal: true

require_relative "lib/paquito/version"

Gem::Specification.new do |spec|
  spec.name          = "paquito"
  spec.version       = Paquito::VERSION
  spec.authors       = ["Jean Boussier"]
  spec.email         = ["jean.boussier@gmail.com"]

  spec.summary       = "Framework for defining efficient and extendable serializers"
  spec.description   = "Framework for defining efficient and extendable serializers"
  spec.homepage      = "https://github.com/Shopify/paquito"
  spec.license       = "MIT"
  spec.required_ruby_version = ">= 2.7.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/Shopify/paquito"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    %x{git ls-files -z}.split("\x0").reject { |f| f.match(%r{\A(?:test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency("msgpack", ">= 1.5.2")
end

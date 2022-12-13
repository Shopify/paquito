# Paquito

`Paquito` provides utility classes to define optimized and evolutive serializers.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'paquito'
```

And then execute:

    $ bundle install

Or install it yourself as:

    $ gem install paquito

## Usage

### `chain`

`Paquito::CoderChain` combines two or more serializers into one.

Example:

```ruby
compressed_yaml_coder = Paquito.chain(YAML, Zlib)
payload = compressed_yaml_coder.dump({ foo: 42 }) # YAML compressed with gzip
compressed_yaml_coder.load(payload) # => { foo: 42 }
```

### `ConditionalCompressor`

`Paquito::ConditionalCompressor` compresses payloads if they are over a defined size.

Example:
```ruby
coder = Paquito::ConditionalCompressor.new(Zlib, 256)
coder.dump("foo") # => "\x00foo"
coder.dump("foo" * 500) # => "\x01<compressed-data....>"
```

### `SingleBytePrefixVersion`

`Paquito::SingleBytePrefixVersion` prepends a version prefix to the payloads, which allows you to seamlessly transition
between different serialization methods.

The first argument is the current version used for newly generated payloads.

Example:

```ruby
coder = Paquito::SingleBytePrefixVersion.new(1,
  0 => YAML,
  1 => JSON,
  2 => MessagePack,
)
coder.dump([1]) # => "\x01[1]"
coder.load("\x00---\n:foo: 42") # => { foo: 42 }
```

### `SingleBytePrefixVersionWithStringBypass`

Works like `Paquito::SingleBytePrefixVersion` except that versions `253`, `254` and `255` are reserved for serializing strings
in an optimized way.

When the object to serialize is an `UTF-8`, `ASCII` or `BINARY` string, rather than invoking the underlying serializer, it simply
prepends a single byte to the string which indicates the encoding.

Additionally, you can pass a distinct serializer for strings only:

Example:

```ruby
coder = Paquito::SingleBytePrefixVersionWithStringBypass.new(
  1,
  { 0 => YAML, 1 => JSON },
  Paquito::ConditionalCompressor.new(Zlib, 1024), # Large strings will be compressed but not serialized in JSON.
)
```

The larger the string the larger the speed gain is, e.g. for a 1MB string, it's over 500x faster than going through `MessagePack` or `Marshal`.

### `CommentPrefixVersion`

Similar to the single byte prefix, but meant to be human readable and to allow for migrating unversioned payloads.

Payloads without a version prefix are assumed to be version `0`.

The first argument is the current version used for newly generated payloads.

Example:

```ruby
coder = Paquito::CommentPrefixVersion.new(1,
  0 => YAML,
  1 => JSON,
)

coder.load("---\n:foo: 42") # => { foo: 42 }
coder.dump([1]) # => "#☠1☢\n[1]"
```

### `allow_nil`

In some situations where you'd rather not serialize `nil`, you can use the `Paquito.allow_nil` shorthand:

```ruby
coder = Paquito.allow_nil(Marshal)
coder.dump(nil) # => nil
coder.load(nil) # => nil
```

### `TranslateErrors`

If you do need to handle serialization or deserialization errors, for instance to fallback to acting like a cache miss,
`Paquito::TranslateErrors` translates all underlying exceptions into `Paquito::Error` descendants.

Example:

```ruby
coder = Paquito::TranslateErrors.new(Paquito::CoderChain.new(YAML, Zlib))
coder.load("\x00") # => Paquito::UnpackError (buffer error)
```

### `CodecFactory`

`Paquito::CodecFactory` is a utility facade to create advanced `MessagePack` factories with support for common Ruby
and Rails types.

Example
```ruby
coder = Paquito::CodecFactory.build([Symbol, Set])
coder.load(coder.dump(%i(foo bar).to_set)) # => #<Set: {:foo, :bar}>
```

### `TypedStruct`

`Paquito::TypedStruct` is a opt-in Sorbet runtime plugin that allows `T::Struct` classes to be serializable. You need
to explicitly include the module in the `T::Struct` classes that you will be serializing.

Example

```ruby
class MyStruct < T::Struct
  include Paquito::TypedStruct

  prop :foo, String
  prop :bar, Integer
end

my_struct = MyStruct.new(foo: "foo", bar: 1)

my_struct.as_pack # => [26450, "foo", 1]
MyStruct.from_pack([26450, "foo", 1]) # => <MyStruct bar=1, foo="foo">
```

## Rails utilities

`paquito` doesn't depend on `rails` or any of its components, however it does provide some optional utilities.

### `CacheEntryCoder`

`Paquito::CacheEntryCoder` turns an `ActiveSupport::Cache::Entry` instance into a simple `Array` instance. This allows
you to implement custom coders for `ActiveSupport::Cache`.

Example:

```ruby
ActiveSupport::Cache::FileStore.new("tmp/cache", coder: Paquito.chain(Paquito::CacheEntryCoder, JSON))
```

### `FlatCacheEntryCoder`

`Paquito::FlatCacheEntryCoder` is a variation of `Paquito::CacheEntryCoder`. Instead of encoding `ActiveSupport::Cache::Entry`
into an Array of three members, it serializes the entry metadata itself and adds it as a prefix to the serialized payload.

This allows to leverage `Paquito::SingleBytePrefixVersionWithStringBypass` effectively.

Example:

```ruby
ActiveSupport::Cache::FileStore.new(
  "tmp/cache",
  coder: Paquito::FlatCacheEntryCoder.new(
    Paquito::SingleBytePrefixVersionWithStringBypass.new(
      1,
      0 => Marshal,
      1 => JSON,
    )
  )
)
```

### `SerializedColumn`

`Paquito::SerializedColumn` allows you to decorate any encoder to behave like Rails's builtin `YAMLColumn`

Example:

```ruby
class Shop < ActiveRecord::Base
  serialize :settings, Paquito::SerializedColumn.new(
    Paquito::CommentPrefixVersion.new(
      1,
      0 => YAML,
      1 => Paquito::CodecFactory.build([Symbol]),
    ),
    Hash,
    attribute_name: :settings,
  )
end

Shop.new.settings # => {}
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake test` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and the created tag, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/Shopify/paquito.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

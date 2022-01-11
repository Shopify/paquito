# frozen_string_literal: true

ActiveRecord::Schema.define do
  create_table :users, force: true do |t|
    t.string(:email)
  end

  create_table :features, force: true do |t|
    t.string(:name)
  end

  create_table :shops, force: true do |t|
    t.string(:name)
    t.binary(:settings)
    t.references(:owner)
  end

  create_table :shop_features, force: true do |t|
    t.references(:shop)
    t.references(:feature)
  end

  create_table :extensions, force: true do |t|
    t.json(:executable)
  end

  create_table :products, force: true do |t|
    t.references(:shop)
    t.string(:name)
    t.integer(:quantity)
  end

  create_table :domains, force: true do |t|
    t.references(:shop)
    t.string(:name)
  end
end

class User < ActiveRecord::Base
  has_many :shops, inverse_of: :owner
end

class Feature < ActiveRecord::Base
end

class ShopFeature < ActiveRecord::Base
  belongs_to :shop
  belongs_to :feature
end

class Shop < ActiveRecord::Base
  belongs_to :owner, class_name: "User"
  has_one :domain
  has_many :products
  has_many :shop_features
  has_many :current_features, class_name: "Feature", through: :shop_features, source: :feature

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

class Product < ActiveRecord::Base
  belongs_to :shop
end

class Domain < ActiveRecord::Base
  belongs_to :shop
end

class Extension < ActiveRecord::Base
end

online_store = Feature.create!(name: "Online Store")

snow_devil = Shop.create!(name: "Snow Devil", settings: { currency: "€" })

ShopFeature.create!(shop: snow_devil, feature: online_store)

snow_devil.create_domain!(name: "example.com")

snow_devil.products.create!(name: "Cheap Snowboard", quantity: 24)
snow_devil.products.create!(name: "Expensive Snowboard", quantity: 2)

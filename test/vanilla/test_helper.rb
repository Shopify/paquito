# frozen_string_literal: true

require File.expand_path("../test_helper.rb", __dir__)

Dir[File.expand_path("support/*.rb", __dir__)].sort.each do |support|
  require support
end

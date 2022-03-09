# frozen_string_literal: true

module Paquito
  class SafeYAML
    ALL_SYMBOLS = [].freeze # Restricting symbols isn't really useful since symbols are no longer immortal
    BASE_PERMITTED_CLASSNAMES = ["TrueClass", "FalseClass", "NilClass", "Numeric", "String", "Array", "Hash",
                                 "Integer", "Float",].freeze

    def initialize(permitted_classes: [], deprecated_classes: [], aliases: false)
      permitted_classes += BASE_PERMITTED_CLASSNAMES
      @dumpable_classes = permitted_classes
      @loadable_classes = permitted_classes + deprecated_classes
      @aliases = aliases

      @dump_options = {
        permitted_classes: permitted_classes,
        permitted_symbols: ALL_SYMBOLS,
        aliases: true,
        line_width: -1, # Disable YAML line-wrapping because it causes extremely obscure issues.
      }.freeze
    end

    def load(serial)
      Psych.safe_load(
        serial,
        permitted_classes: @loadable_classes,
        permitted_symbols: ALL_SYMBOLS,
        aliases: @aliases,
      )
    rescue Psych::DisallowedClass => psych_error
      raise UnsupportedType, psych_error.message
    rescue Psych::Exception => psych_error
      raise UnpackError, psych_error.message
    end

    def dump(obj)
      visitor = RestrictedYAMLTree.create(@dump_options)
      visitor << obj
      visitor.tree.yaml(nil, @dump_options)
    rescue Psych::Exception => psych_error
      raise PackError, psych_error.message
    end

    class RestrictedYAMLTree < Psych::Visitors::YAMLTree
      class DispatchCache
        def initialize(visitor, cache)
          @visitor = visitor
          @cache = cache
        end

        def [](klass)
          @cache[klass] if @visitor.permitted_class?(klass)
        end
      end

      def initialize(...)
        super
        @permitted_classes = Set.new(@options[:permitted_classes])
        @dispatch_cache = DispatchCache.new(self, @dispatch_cache)
        @permitted_cache = Hash.new do |h, klass|
          unless @permitted_classes.include?(klass.name)
            raise UnsupportedType, "Tried to dump unspecified class: #{klass.name.inspect}"
          end

          h[klass] = true
        end.compare_by_identity
      end

      def dump_coder(target)
        return unless permitted_class?(target.class)

        super
      end

      def permitted_class?(klass)
        @permitted_cache[klass]
      end
    end
  end
end

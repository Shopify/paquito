# frozen_string_literal: true

module Paquito
  module ColumnsDigestCache
    extend ActiveSupport::Concern

    class_methods do
      def reload_schema_from_cache(*)
        super
        @paquito_columns_digest = nil
      end

      def paquito_columns_digest
        @paquito_columns_digest ||= Paquito::ActiveRecordCoder.columns_digest(self)
      end
    end
  end
end

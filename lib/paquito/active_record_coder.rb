# frozen_string_literal: true

require "paquito/errors"

module Paquito
  class ActiveRecordCoder
    class << self
      def dump(record)
        instances = InstanceTracker.new
        serialized_associations = serialize_associations(record, instances)
        serialized_records = instances.map { |r| serialize_record(r) }
        [serialized_associations, *serialized_records]
      end

      def load(payload)
        instances = InstanceTracker.new
        serialized_associations, *serialized_records = payload
        serialized_records.each { |attrs| instances.push(deserialize_record(*attrs)) }
        deserialize_associations(serialized_associations, instances)
      end

      private

      # Records without associations, or which have already been visited before,
      # are serialized by their id alone.
      #
      # Records with associations are serialized as a two-element array including
      # their id and the record's association cache.
      #
      def serialize_associations(record, instances)
        return unless record

        if (id = instances.lookup(record))
          payload = id
        else
          payload = instances.push(record)

          cached_associations = record.class.reflect_on_all_associations.select do |reflection|
            record.association_cached?(reflection.name)
          end

          unless cached_associations.empty?
            serialized_associations = cached_associations.map do |reflection|
              association = record.association(reflection.name)

              serialized_target = if reflection.collection?
                association.target.map { |target_record| serialize_associations(target_record, instances) }
              else
                serialize_associations(association.target, instances)
              end

              [reflection.name, serialized_target]
            end

            payload = [payload, serialized_associations]
          end
        end

        payload
      end

      def deserialize_associations(payload, instances)
        return unless payload

        id, associations = payload
        record = instances.fetch(id)

        associations&.each do |name, serialized_target|
          begin
            association = record.association(name)
          rescue ActiveRecord::AssociationNotFoundError
            raise AssociationMissingError, "undefined association: #{name}"
          end

          target = if association.reflection.collection?
            serialized_target.map! { |serialized_record| deserialize_associations(serialized_record, instances) }
          else
            deserialize_associations(serialized_target, instances)
          end

          association.target = target
        end

        record
      end

      def serialize_record(record)
        [record.class.name, attributes_for_database(record)]
      end

      def attributes_for_database(record)
        attributes = record.attributes_for_database
        attributes.transform_values! { |attr| attr.is_a?(::ActiveModel::Type::Binary::Data) ? attr.to_s : attr }
        attributes
      end

      def deserialize_record(class_name, attributes_from_database)
        begin
          klass = Object.const_get(class_name)
        rescue NameError
          raise ClassMissingError, "undefined class: #{class_name}"
        end

        klass.instantiate(attributes_from_database).tap do |record|
          next unless record.public_send(klass.primary_key).nil?

          record.instance_variable_set(:@new_record, true)
        end
      end
    end

    class Error < ::Paquito::Error
    end

    class ClassMissingError < Error
    end

    class AssociationMissingError < Error
    end

    class InstanceTracker
      def initialize
        @instances = []
        @ids = {}.compare_by_identity
      end

      def map(&block)
        @instances.map(&block)
      end

      def fetch(*args, &block)
        @instances.fetch(*args, &block)
      end
      ruby2_keywords :fetch if respond_to?(:ruby2_keywords, true)

      def push(instance)
        id = @ids[instance] = @instances.size
        @instances << instance
        id
      end

      def lookup(instance)
        @ids[instance]
      end
    end
  end
end

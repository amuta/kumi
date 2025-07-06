module Kumi
  module ActiveModelBridge
    extend ActiveSupport::Concern

    class_methods do
      # Example: has_traits UserTraits
      def has_traits(schema_klass)
        compiled = schema_klass.compiled_schema # memoised
        exposed = schema_klass.generated_schema # AST
                              .attributes.map(&:name) +
                  schema_klass.generated_schema.traits.map(&:name)
        exposed &= if schema_klass.respond_to?(:exposed_names)
                     schema_klass.exposed_names
                   else
                     exposed
                   end

        define_method :_trait_engine_context do
          # Convert model to a hash the schema expects
          @__trait_ctx ||= begin
            attrs = attributes.symbolize_keys
            # also expose arbitrary methods like #roles, etc.
            attrs.merge(
              roles: roles,
              feature_flags: feature_flags
            )
          end
        end

        exposed.each do |binding_name|
          define_method "#{binding_name}?" do
            compiled.evaluate_binding(binding_name, _trait_engine_context)
          end
        end
      end
    end
  end
end

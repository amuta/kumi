# frozen_string_literal: true

module Kumi
  module IR
    module Testing
      module SnastFactory
        module_function

        def build
          builder = ModuleBuilder.new
          yield builder
          builder.build
        end

        def snast_module(declarations = {})
          decls = declarations.transform_values { ensure_declaration(_1) }
          Kumi::Core::NAST::Module.new(decls:)
        end

        def declaration(name, body:, kind: :value, axes: [], dtype: nil, meta: {}, loc: nil, id: nil)
          declarative_meta = meta.dup
          declarative_meta[:kind] ||= kind
          declarative_meta[:stamp] ||= stamp(axes:, dtype:)

          Kumi::Core::NAST::Declaration.new(
            id: id,
            name: name,
            body:,
            loc: loc,
            meta: declarative_meta
          )
        end

        def const(value, dtype:, axes: [], loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Const.new(value:, loc:, meta: node_meta, id:)
        end

        def input_ref(path:, axes:, dtype:, key_chain: [], loc: nil, id: nil, fqn: nil, meta: {})
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::InputRef.new(
            path: Array(path),
            fqn: fqn,
            key_chain: key_chain,
            loc:,
            meta: node_meta,
            id:
          )
        end

        def ref(name:, axes: [], dtype: nil, loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Ref.new(name:, loc:, meta: node_meta, id:)
        end

        def tuple(args:, axes: [], dtype: nil, loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Tuple.new(args:, loc:, meta: node_meta, id:)
        end

        def hash(pairs:, axes: [], dtype: nil, loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Hash.new(pairs:, loc:, meta: node_meta, id:)
        end

        def pair(key:, value:, axes: [], dtype: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Pair.new(key:, value:, meta: node_meta, id:)
        end

        def call(fn:, args:, axes: [], dtype: nil, loc: nil, opts: {}, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Call.new(fn:, args:, opts:, loc:, meta: node_meta, id:)
        end

        def select(cond:, on_true:, on_false:, axes: [], dtype: nil, loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Select.new(cond:, on_true:, on_false:, loc:, meta: node_meta, id:)
        end

        def fold(fn:, arg:, axes: [], dtype: nil, loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Fold.new(fn:, arg:, loc:, meta: node_meta, id:)
        end

        def reduce(fn:, arg:, over:, axes: [], dtype: nil, loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::Reduce.new(fn:, arg:, over:, loc:, meta: node_meta, id:)
        end

        def index_ref(name:, input_fqn:, axes: [], dtype: nil, loc: nil, meta: {}, id: nil)
          node_meta = merge_stamp(meta, axes:, dtype:)
          Kumi::Core::NAST::IndexRef.new(name:, input_fqn:, loc:, meta: node_meta, id:)
        end

        def stamp(axes:, dtype:)
          return nil if axes.nil? && dtype.nil?

          {
            axes: Array(axes || []),
            dtype: normalize_dtype(dtype)
          }
        end

        def merge_stamp(meta, axes:, dtype:)
          out = meta.dup
          s = stamp(axes:, dtype:)
          if s
            out[:stamp] = (out[:stamp] || {}).merge(s)
          end
          out
        end

        def normalize_dtype(dtype)
          return nil if dtype.nil?
          return dtype if dtype.is_a?(Kumi::Core::Types::Type)

          Kumi::Core::Types.normalize(dtype)
        end

        def ensure_declaration(val)
          return val if val.is_a?(Kumi::Core::NAST::Declaration)

          raise ArgumentError, "expected NAST::Declaration, got #{val.class}"
        end

        class ModuleBuilder
          def initialize
            @decls = {}
          end

          def declaration(name, **opts, &block)
            raise ArgumentError, "declaration requires block" unless block

            body = block.call
            @decls[name.to_sym] = SnastFactory.declaration(name, body:, **opts)
          end

          def build
            SnastFactory.snast_module(@decls)
          end
        end
      end
    end
  end
end

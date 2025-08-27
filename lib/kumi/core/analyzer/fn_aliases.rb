# frozen_string_literal: true

module Kumi
  module Core
    module Analyzer
      module FnAliases
        # Canonical names use simple domains:
        # - core.*  : elementwise / structural ops
        # - agg.*   : reductions (sum, etc.)
        #
        # NOTE: keep this lexical-only. Overload resolution (e.g. length on string vs array)
        #       should happen in a later resolver pass.

        MAP = {
          # already-canonical → itself (idempotent)
          :'core.add'    => :'core.add',
          :'core.sub'    => :'core.sub',
          :'core.mul'    => :'core.mul',
          :'core.div'    => :'core.div',
          :'core.mod'    => :'core.mod',
          :'core.pow'    => :'core.pow',
          :'core.eq'     => :'core.eq',
          :'core.neq'    => :'core.neq',
          :'core.gt'     => :'core.gt',
          :'core.gte'    => :'core.gte',
          :'core.lt'     => :'core.lt',
          :'core.lte'    => :'core.lte',
          :'core.and'    => :'core.and',
          :'core.or'     => :'core.or',
          :'core.not'    => :'core.not',
          :'core.at'     => :'core.at',
          :'core.concat' => :'core.concat',
          :'core.length' => :'core.length',
          :'core.first'  => :'core.first',
          :'core.last'   => :'core.last',
          :'core.sort'   => :'core.sort',
          :'core.reverse'=> :'core.reverse',
          :'core.unique' => :'core.unique',
          :'core.min'    => :'core.min',
          :'core.max'    => :'core.max',
          :'core.empty?' => :'core.empty?',
          :'core.flatten'=> :'core.flatten',
          :'core.include?' => :'core.include?',
          :'core.select' => :'core.select',
          :'core.array'  => :'core.array',
          :'core.map_with_index' => :'core.map_with_index',
          :'core.indices'=> :'core.indices',
          :'agg.sum'     => :'agg.sum',

          # arithmetic sugar (your parser emits :add/:subtract/etc and raw operators)
          :add       => :'core.add',
          :subtract  => :'core.sub',
          :multiply  => :'core.mul',
          :divide    => :'core.div',
          :modulo    => :'core.mod',
          :power     => :'core.pow',
          :+         => :'core.add',
          :-         => :'core.sub',
          :*         => :'core.mul',
          :/         => :'core.div',
          :%         => :'core.mod',
          :**        => :'core.pow',

          # comparisons (parser currently emits operator symbols)
          :"=="      => :'core.eq',
          :"!="      => :'core.neq',
          :">"       => :'core.gt',
          :">="      => :'core.gte',
          :"<"       => :'core.lt',
          :"<="      => :'core.lte',

          # booleans
          :and       => :'core.and',
          :or        => :'core.or',
          :not       => :'core.not',
          :"&&"      => :'core.and',
          :"||"      => :'core.or',
          :"!"       => :'core.not',

          # indexing / structural
          :at        => :'core.at',
          :concat    => :'core.concat',
          :size      => :'core.length',
          :length    => :'core.length',
          :first     => :'core.first',
          :last      => :'core.last',
          :sort      => :'core.sort',
          :reverse   => :'core.reverse',
          :unique    => :'core.unique',
          :min       => :'core.min',
          :max       => :'core.max',
          :empty?    => :'core.empty?',
          :flatten   => :'core.flatten',
          :include?  => :'core.include?',

          # control / arrays
          :if        => :'core.select',  # normalize to select
          :select    => :'core.select',
          :array     => :'core.array',

          # array helpers your sugar exposes
          :map_with_index => :'core.map_with_index',
          :indices        => :'core.indices',

          # reductions called as methods on arrays (reserve as agg.*)
          :sum       => :'agg.sum'
        }.freeze

        # Public: normalize any fn identifier (String/Symbol) to canonical Symbol.
        # Unknown names are returned unchanged (as Symbol).
        def self.canonical(fn)
          key =
            case fn
            when Symbol then fn
            when String then fn.strip.downcase.to_sym
            else fn.to_s.strip.downcase.to_sym
            end

          MAP.fetch(key, key)
        end
      end
    end
  end
end
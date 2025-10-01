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
          :+ => :"core.add",
          :- => :"core.sub",
          :* => :"core.mul",
          :/ => :"core.div",
          :% => :"core.mod",
          :** => :"core.pow",
          :"==" => :"core.eq",
          :"!=" => :"core.neq",
          :">" => :"core.gt",
          :">=" => :"core.gte",
          :"<" => :"core.lt",
          :"<=" => :"core.lte",
          :"&" => :"core.and",
          :"!" => :"core.not"
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

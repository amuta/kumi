# frozen_string_literal: true

module Kumi
  module IR
    module Loop
      autoload :Ops, "kumi/ir/loop/ops"
      autoload :Lower, "kumi/ir/loop/lower"
      autoload :Pipeline, "kumi/ir/loop/pipeline"
      autoload :Builder, "kumi/ir/loop/builder"
      autoload :Validator, "kumi/ir/loop/validator"

      class Function < Base::Function
        attr_reader :return_reg

        def initialize(name:, return_reg:, **kwargs)
          super(name:, **kwargs)
          @return_reg = return_reg
        end
      end

      class Module < Base::Module
        def self.from_vec(vec_module, context: {})
          Lower.new(vec_module: vec_module, context: context).call
        end
      end
    end
  end
end

# frozen_string_literal: true

# LoopIR used to host a structured loop representation, but that pipeline has
# been removed while VecIR/BufIR are brought online. The module intentionally
# stays empty so existing requires keep working without loading stale code.
module Kumi
  module IR
    module Loop
      def self.future_work!
        raise NotImplementedError, "LoopIR has been removed; this is a placeholder for future work"
      end
    end
  end
end

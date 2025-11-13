# frozen_string_literal: true

module Kumi
  module IR
    autoload :Base,    "kumi/ir/base"
    autoload :DF,      "kumi/ir/df"
    autoload :Loop,    "kumi/ir/loop"
    autoload :Buf,     "kumi/ir/buf"
    autoload :Vec,     "kumi/ir/vec"
    autoload :Printer, "kumi/ir/printer"
    autoload :Testing, "kumi/ir/testing"
  end
end

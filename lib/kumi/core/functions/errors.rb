# frozen_string_literal: true

module Kumi
  module Core
    module Functions
      class SignatureError < StandardError; end
      class SignatureParseError < SignatureError; end
      class SignatureMatchError < SignatureError; end
    end
  end
end

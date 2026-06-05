# frozen_string_literal: true

module RubyLLM
  module Tokenizer
    Analysis = Struct.new(:tokens, :ids, :model, keyword_init: true) do
      def count
        ids.size
      end

      def to_h
        { tokens: tokens, ids: ids, model: model, count: count }
      end
    end
  end
end

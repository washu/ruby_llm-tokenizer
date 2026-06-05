# frozen_string_literal: true

module RubyLLM
  module Tokenizer
    class Error < StandardError; end

    class UnknownModelError < Error; end

    class BackendError < Error; end

    class CacheError < Error; end

    class ContextExceededError < Error
      attr_reader :token_count, :limit, :model

      def initialize(message = nil, token_count: nil, limit: nil, model: nil)
        super(message)
        @token_count = token_count
        @limit = limit
        @model = model
      end
    end
  end
end

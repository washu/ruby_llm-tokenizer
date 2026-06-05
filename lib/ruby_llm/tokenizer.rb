# frozen_string_literal: true

require_relative "tokenizer/version"
require_relative "tokenizer/errors"
require_relative "tokenizer/configuration"
require_relative "tokenizer/analysis"
require_relative "tokenizer/registry"

module RubyLLM
  module Tokenizer
    class << self
      def count(text, model:)
        backend_for(model).count(text)
      end

      def analyze(text, model:)
        backend_for(model).analyze(text)
      end

      def truncate(text, max_tokens:, model:, overflow: :truncate_right)
        backend_for(model).truncate(text, max_tokens: max_tokens, overflow: overflow)
      end

      def register(match:, backend:, **)
        registry.register(match: match, backend: backend, **)
      end

      # Opt-in: route any "claude*" model to an approximation backend.
      # Counts are not exact. See Backend::Approximate for caveats.
      def enable_claude_approximation!(encoding: "o200k_base")
        registry.register(match: /^claude/i, backend: :approximate, encoding: encoding)
      end

      def configure
        yield configuration
      end

      def configuration
        @configuration ||= Configuration.new
      end

      def registry
        @registry ||= Registry.load_default
      end

      def reset!
        @configuration = nil
        @registry = nil
      end

      private

      def backend_for(model)
        registry.resolve(model) ||
          raise(UnknownModelError, "No tokenizer configured for model: #{model.inspect}")
      end
    end
  end
end

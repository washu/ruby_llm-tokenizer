# frozen_string_literal: true

require_relative "tiktoken"

module RubyLLM
  module Tokenizer
    module Backend
      # Approximate tokenizer for models with no published tokenizer (notably
      # Anthropic Claude). Wraps a tiktoken encoding as a stand-in. Token counts
      # are typically within ~5-15% of the model's true count and should not be
      # used for hard limits.
      class Approximate < Tiktoken
        def initialize(encoding: "o200k_base")
          super
          @warned = false
          @warn_mutex = Mutex.new
        end

        def encode(text)
          warn_once
          super
        end

        def identifier
          "approximate:#{encoding_name}"
        end

        private

        def warn_once
          return if @warned
          return unless RubyLLM::Tokenizer.configuration.approximate_warn

          @warn_mutex.synchronize do
            return if @warned

            Kernel.warn(warning_message)
            @warned = true
          end
        end

        def warning_message
          "[ruby_llm-tokenizer] Using approximate tokenizer (#{encoding_name}). " \
            "Counts may differ from the model's true tokenizer by ~5-15%. " \
            "Silence with: RubyLLM::Tokenizer.configure { |c| c.approximate_warn = false }"
        end
      end
    end
  end
end

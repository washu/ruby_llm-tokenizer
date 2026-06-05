# frozen_string_literal: true

require "tiktoken_ruby"
require_relative "../backend"

module RubyLLM
  module Tokenizer
    module Backend
      class Tiktoken < Base
        attr_reader :encoding_name

        def initialize(encoding:)
          super()
          @encoding_name = encoding.to_s
          @encoding = ::Tiktoken.get_encoding(@encoding_name)
          raise BackendError, "Unknown tiktoken encoding: #{encoding.inspect}" if @encoding.nil?
        rescue BackendError
          raise
        rescue StandardError => e
          raise BackendError, "Failed to load tiktoken encoding #{encoding.inspect}: #{e.message}"
        end

        def encode(text)
          @encoding.encode(text.to_s)
        end

        def decode(ids)
          @encoding.decode(Array(ids))
        end

        def identifier
          "tiktoken:#{encoding_name}"
        end
      end
    end
  end
end

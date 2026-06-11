# frozen_string_literal: true

require_relative "../backend"

module RubyLLM
  module Tokenizer
    module Backend
      class SentencePiece < Base
        attr_reader :model_file

        def initialize(model_file: nil, model_file_env: nil)
          super()
          @model_file = resolve_model_file(model_file, model_file_env)
          processor_class = load_sentencepiece_processor_class
          @tokenizer = processor_class.new(model_file: @model_file)
        rescue StandardError => e
          raise BackendError, "Failed to load SentencePiece model #{@model_file.inspect}: #{e.message}"
        end

        def encode(text)
          @tokenizer.public_send(:encode_as_ids, text.to_s)
        end

        def decode(ids)
          @tokenizer.public_send(:decode, Array(ids))
        end

        def analyze(text)
          text = text.to_s
          ids = @tokenizer.public_send(:encode_as_ids, text)
          tokens = @tokenizer.public_send(:encode, text, out_type: "str")
          Analysis.new(tokens: tokens, ids: ids, model: identifier)
        end

        def identifier
          "sentencepiece:#{model_file}"
        end

        private

        def resolve_model_file(model_file, model_file_env)
          return model_file.to_s unless model_file.nil? || model_file.to_s.empty?

          if model_file_env && !model_file_env.to_s.empty?
            env_value = ENV.fetch(model_file_env.to_s, nil)
            return env_value.to_s unless env_value.nil? || env_value.to_s.empty?
          end

          raise BackendError,
                "SentencePiece backend requires :model_file or :model_file_env with a configured path"
        end

        def load_sentencepiece_processor_class
          Object.const_get(:SentencePiece).const_get(:SentencePieceProcessor)
        rescue NameError
          begin
            require "sentencepiece"
            Object.const_get(:SentencePiece).const_get(:SentencePieceProcessor)
          rescue LoadError => e
            raise BackendError,
                  "SentencePiece backend requires the sentencepiece gem and a compiled SentencePiece library: #{e.message}"
          rescue NameError => e
            raise BackendError,
                  "SentencePiece backend requires SentencePieceProcessor to be available: #{e.message}"
          end
        end
      end
    end
  end
end


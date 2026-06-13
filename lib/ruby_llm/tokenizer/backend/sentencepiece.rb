# frozen_string_literal: true

require_relative "../backend"

module RubyLLM
  module Tokenizer
    module Backend
      class SentencePiece < Base
        attr_reader :model_file

        def initialize(model_file: nil, model_file_env: nil, default_model_file: nil)
          super()
          @model_file = resolve_model_file(model_file, model_file_env, default_model_file)
          processor_class = load_sentencepiece_processor_class
          @tokenizer = processor_class.new(model_file: @model_file)
        rescue StandardError => e
          raise BackendError, "Failed to load SentencePiece model #{@model_file.inspect}: #{e.message}"
        end

        def encode(text)
          @tokenizer.encode_as_ids(text.to_s)
        end

        def decode(ids)
          @tokenizer.decode(Array(ids))
        end

        def analyze(text)
          text = text.to_s
          ids = @tokenizer.encode_as_ids(text)
          tokens = @tokenizer.encode(text, out_type: "str")
          Analysis.new(tokens: tokens, ids: ids, model: identifier)
        end

        def identifier
          "sentencepiece:#{model_file}"
        end

        private

        def resolve_model_file(model_file, model_file_env, default_model_file)
          explicit_model_file(model_file) || env_model_file(model_file_env) || default_model_file(default_model_file) ||
            raise_missing_model_file
        end

        def explicit_model_file(model_file)
          return if model_file.nil? || model_file.to_s.empty?

          model_file.to_s
        end

        def env_model_file(model_file_env)
          return if model_file_env.nil? || model_file_env.to_s.empty?

          env_value = ENV.fetch(model_file_env.to_s, nil)
          return if env_value.nil? || env_value.to_s.empty?

          env_value.to_s
        end

        def default_model_file(default_model_file)
          return if default_model_file.nil? || default_model_file.to_s.empty?

          default_model_file.to_s
        end

        def raise_missing_model_file
          raise BackendError,
                "SentencePiece backend requires :model_file, :model_file_env, or " \
                ":default_model_file with a configured path"
        end

        def load_sentencepiece_processor_class
          sentencepiece_processor_class || load_sentencepiece_gem
        end

        def sentencepiece_processor_class
          Object.const_get(:SentencePiece).const_get(:SentencePieceProcessor)
        rescue NameError
          nil
        end

        def load_sentencepiece_gem
          require "sentencepiece"
          sentencepiece_processor_class || raise_missing_processor_constant
        rescue LoadError => e
          raise BackendError,
                "SentencePiece backend requires the sentencepiece gem and a " \
                "compiled SentencePiece library: #{e.message}"
        end

        def raise_missing_processor_constant
          raise BackendError,
                "SentencePiece backend requires SentencePieceProcessor to be available"
        end
      end
    end
  end
end

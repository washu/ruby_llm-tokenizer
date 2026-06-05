# frozen_string_literal: true

require_relative "analysis"
require_relative "errors"

module RubyLLM
  module Tokenizer
    module Backend
      class Base
        def encode(_text)
          raise NotImplementedError, "#{self.class}#encode must be implemented"
        end

        def decode(_ids)
          raise NotImplementedError, "#{self.class}#decode must be implemented"
        end

        def count(text)
          encode(text).size
        end

        def analyze(text)
          ids = encode(text)
          Analysis.new(tokens: ids.map { |id| decode_single(id) }, ids: ids, model: identifier)
        end

        def truncate(text, max_tokens:, overflow: :truncate_right)
          ids = encode(text)
          return text.to_s if ids.size <= max_tokens

          kept = case overflow
                 when :truncate_right then ids.first(max_tokens)
                 when :truncate_left  then ids.last(max_tokens)
                 else raise ArgumentError, "Unknown overflow strategy: #{overflow.inspect}"
                 end
          decode(kept)
        end

        def identifier
          self.class.name.split("::").last.downcase
        end

        private

        def decode_single(id)
          decode([id])
        end
      end
    end
  end
end

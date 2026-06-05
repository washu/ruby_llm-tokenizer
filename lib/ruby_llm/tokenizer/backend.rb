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
          validate_max_tokens!(max_tokens)
          validate_overflow!(overflow)
          return "" if max_tokens.zero?

          if text.respond_to?(:to_str) || !text.respond_to?(:each)
            truncate_string(text.to_s, max_tokens: max_tokens, overflow: overflow)
          else
            truncate_stream(text, max_tokens: max_tokens, overflow: overflow)
          end
        end

        def identifier
          self.class.name.split("::").last.downcase
        end

        private

        def truncate_string(text, max_tokens:, overflow:)
          ids = encode(text)
          return text if ids.size <= max_tokens

          decode(kept_ids(ids, max_tokens: max_tokens, overflow: overflow))
        end

        def truncate_stream(stream, max_tokens:, overflow:)
          if overflow == :truncate_right
            truncate_stream_right(stream, max_tokens)
          else
            truncate_stream_left(stream, max_tokens)
          end
        end

        def truncate_stream_right(stream, max_tokens)
          buffer = +""

          each_chunk(stream) do |chunk|
            buffer << chunk
            ids = encode(buffer)
            return decode(kept_ids(ids, max_tokens: max_tokens, overflow: :truncate_right)) if ids.size > max_tokens
          end

          buffer
        end

        def truncate_stream_left(stream, max_tokens)
          buffer = +""

          each_chunk(stream) do |chunk|
            buffer << chunk
            ids = encode(buffer)
            buffer = decode(kept_ids(ids, max_tokens: max_tokens, overflow: :truncate_left)) if ids.size > max_tokens
          end

          buffer
        end

        def kept_ids(ids, max_tokens:, overflow:)
          overflow == :truncate_right ? ids.first(max_tokens) : ids.last(max_tokens)
        end

        def each_chunk(stream)
          stream.each do |chunk|
            next if chunk.nil?

            piece = chunk.to_s
            next if piece.empty?

            yield piece
          end
        end

        def validate_max_tokens!(max_tokens)
          raise ArgumentError, "max_tokens must be an Integer" unless max_tokens.is_a?(Integer)
          raise ArgumentError, "max_tokens must be >= 0" if max_tokens.negative?
        end

        def validate_overflow!(overflow)
          return if %i[truncate_right truncate_left].include?(overflow)

          raise ArgumentError, "Unknown overflow strategy: #{overflow.inspect}"
        end

        def decode_single(id)
          decode([id])
        end
      end
    end
  end
end

# frozen_string_literal: true

require "fileutils"
require "tokenizers"
require_relative "../backend"

module RubyLLM
  module Tokenizer
    module Backend
      class HuggingFace < Base
        attr_reader :repo, :revision

        def initialize(repo:, revision: nil)
          super()
          @repo = repo
          @revision = revision
          @tokenizer = load_tokenizer
        end

        def encode(text)
          @tokenizer.encode(text.to_s).ids
        end

        def decode(ids)
          @tokenizer.decode(Array(ids), skip_special_tokens: true)
        end

        def analyze(text)
          encoding = @tokenizer.encode(text.to_s)
          Analysis.new(tokens: encoding.tokens, ids: encoding.ids, model: identifier)
        end

        def identifier
          "hugging_face:#{repo}#{"@#{revision}" if revision}"
        end

        private

        def load_tokenizer
          config = RubyLLM::Tokenizer.configuration
          config.offline ? load_from_disk(config) : load_from_hub(config)
        rescue CacheError
          raise
        rescue StandardError => e
          raise BackendError, "Failed to load Hugging Face tokenizer #{@repo.inspect}: #{e.message}"
        end

        def load_from_disk(config)
          path = local_tokenizer_path(config)
          raise CacheError, "Tokenizer not cached at #{path}" unless File.exist?(path)

          ::Tokenizers.from_file(path.to_s)
        end

        def load_from_hub(config)
          args = { auth_token: config.hf_token }.compact
          args[:revision] = @revision if @revision
          tokenizer = ::Tokenizers.from_pretrained(@repo, **args)
          persist_to_cache(tokenizer, config)
          tokenizer
        end

        def local_tokenizer_path(config)
          config.cache_dir.join(@repo.tr("/", "-"), "tokenizer.json")
        end

        def persist_to_cache(tokenizer, config)
          path = local_tokenizer_path(config)
          FileUtils.mkdir_p(path.dirname)
          tokenizer.save(path.to_s)
        end
      end
    end
  end
end

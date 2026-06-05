# frozen_string_literal: true

require "pathname"

module RubyLLM
  module Tokenizer
    class Configuration
      attr_accessor :cache_dir, :offline, :hf_token, :approximate_warn

      def initialize
        @cache_dir = default_cache_dir
        @offline = false
        @hf_token = ENV["HF_TOKEN"] || ENV.fetch("HUGGING_FACE_HUB_TOKEN", nil)
        @approximate_warn = true
      end

      def default_cache_dir
        base = ENV["XDG_CACHE_HOME"] || File.join(Dir.home, ".cache")
        Pathname.new(File.join(base, "ruby_llm", "tokenizer"))
      end
    end
  end
end

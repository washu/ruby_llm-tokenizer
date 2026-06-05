# frozen_string_literal: true

require "yaml"
require_relative "errors"
require_relative "backend/tiktoken"
require_relative "backend/hugging_face"
require_relative "backend/approximate"

module RubyLLM
  module Tokenizer
    class Registry
      Entry = Struct.new(:match, :backend, :options, keyword_init: true) do
        def matches?(model)
          case match
          when Regexp then match.match?(model.to_s)
          when String then match == model.to_s
          else false
          end
        end
      end

      DEFAULTS_PATH = File.expand_path("models.yml", __dir__)

      def self.load_default
        new.tap { |r| r.load_defaults_from(DEFAULTS_PATH) }
      end

      def initialize
        @entries = []
        @cache = {}
      end

      # User registrations take precedence over built-ins.
      def register(match:, backend:, **options)
        @entries.unshift(Entry.new(match: match, backend: backend.to_sym, options: options))
        @cache.clear
        self
      end

      def resolve(model)
        @cache[model.to_s] ||= begin
          entry = @entries.find { |e| e.matches?(model) }
          entry && build_backend(entry, model.to_s)
        end
      end

      def entries
        @entries.dup
      end

      def clear
        @entries.clear
        @cache.clear
        self
      end

      def load_defaults_from(path)
        data = YAML.load_file(path) || []
        data.each { |entry| @entries.push(build_entry(entry)) }
        @cache.clear
        self
      end

      def build_entry(raw)
        options = raw.except("match", "backend").transform_keys(&:to_sym)
        Entry.new(
          match: self.class.parse_match(raw["match"]),
          backend: raw["backend"].to_sym,
          options: options
        )
      end

      def self.parse_match(value)
        if value.is_a?(String) && (md = value.match(%r{\A/(.*)/([imx]*)\z}))
          flags = 0
          flags |= Regexp::IGNORECASE if md[2].include?("i")
          flags |= Regexp::MULTILINE  if md[2].include?("m")
          flags |= Regexp::EXTENDED   if md[2].include?("x")
          Regexp.new(md[1], flags)
        else
          value
        end
      end

      private

      def build_backend(entry, model)
        case entry.backend
        when :tiktoken      then Backend::Tiktoken.new(**entry.options)
        when :tiktoken_auto then build_tiktoken_auto(model)
        when :hugging_face  then Backend::HuggingFace.new(**entry.options)
        when :approximate   then Backend::Approximate.new(**entry.options)
        else
          raise BackendError, "Unknown backend: #{entry.backend.inspect}"
        end
      end

      def build_tiktoken_auto(model)
        enc = ::Tiktoken.encoding_for_model(model)
        if enc.nil?
          raise UnknownModelError,
                "tiktoken_ruby has no encoding mapping for #{model.inspect}. " \
                "Either upgrade tiktoken_ruby or register an explicit mapping with " \
                "RubyLLM::Tokenizer.register(match: #{model.inspect}, backend: :tiktoken, encoding: \"...\")."
        end

        Backend::Tiktoken.new(encoding: enc.name)
      end
    end
  end
end

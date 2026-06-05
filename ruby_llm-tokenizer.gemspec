# frozen_string_literal: true

require_relative "lib/ruby_llm/tokenizer/version"

Gem::Specification.new do |spec|
  spec.name = "ruby_llm-tokenizer"
  spec.version = RubyLLM::Tokenizer::VERSION
  spec.authors = ["Sal Scotto"]
  spec.email = ["sal.scotto@gmail.com"]

  spec.summary = "Local, model-aware token counting for ruby_llm."
  spec.description = <<~DESC
    Pure-Ruby facade over Hugging Face `tokenizers` and OpenAI `tiktoken_ruby`
    that maps ruby_llm model identifiers (gpt-4o, llama-3, mistral, ...) to the
    correct tokenizer and exposes a small API for counting, analyzing, and
    truncating text against a model's context window. Includes an opt-in
    approximation backend for models with no published tokenizer (Claude).
  DESC
  spec.homepage = "https://github.com/washu/ruby_llm-tokenizer"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "#{spec.homepage}/tree/main"
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  gemspec = File.basename(__FILE__)
  spec.files = IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
    ls.readlines("\x0", chomp: true).reject do |f|
      (f == gemspec) ||
        f.start_with?(*%w[bin/ test/ spec/ features/ .git appveyor Gemfile])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "tiktoken_ruby", "~> 0.0.9"
  spec.add_dependency "tokenizers", "~> 0.5"
end

## [Unreleased]

## [0.1.0] - 2026-06-05

- Initial release.
- `RubyLLM::Tokenizer.count`, `.analyze`, `.truncate` covering OpenAI (tiktoken)
  and open-weight (Hugging Face `tokenizers`) model families.
- Data-driven model registry (`lib/ruby_llm/tokenizer/models.yml`) with runtime
  `.register` for custom patterns.
- Opt-in approximate tokenizer for Anthropic Claude via
  `RubyLLM::Tokenizer.enable_claude_approximation!`.

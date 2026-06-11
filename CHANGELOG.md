## [Unreleased]

## [0.1.1] - 2026-06-11

- Bumped the gem version.
- Added a post-install notice explaining that SentencePiece-backed models require
  the native SentencePiece library and how to install it on macOS and Debian/Ubuntu.

## [0.1.0] - 2026-06-05

- Initial release.
- `RubyLLM::Tokenizer.count`, `.analyze`, `.truncate` covering OpenAI (tiktoken)
  and open-weight (Hugging Face `tokenizers`) model families.
- `RubyLLM::Tokenizer.truncate` accepts plain strings and stream-like `Enumerable`
  inputs (for example `File.foreach(...)`) for exact token-aware truncation.
- `truncate` validates `max_tokens` explicitly and raises `ArgumentError` for
  non-integer or negative values.
- Data-driven model registry (`lib/ruby_llm/tokenizer/models.yml`) with runtime
  `.register` for custom patterns.
- Opt-in approximate tokenizer for Anthropic Claude via
  `RubyLLM::Tokenizer.enable_claude_approximation!`.
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) — runs RSpec on Ruby 3.1–3.4
  for every push and pull request; includes an enforced RuboCop lint step.
- CI badge in README.
- README now documents that `HUGGING_FACE_HUB_TOKEN` is accepted as an alternative to
  `HF_TOKEN` for Hugging Face gated repository access.
- Hugging Face tokenizers fetched from the Hub are persisted under `cache_dir` for
  later offline reuse.



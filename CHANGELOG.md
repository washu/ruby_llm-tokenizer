## [Unreleased]

### Fixed
- **Registry cache nil-result bug** — `Registry#resolve` previously used `||=` to
  memoize backend lookups, which silently skipped caching `nil` (no match). Repeated
  lookups for unknown models would re-scan the entire entry list on every call.
  Now uses `Hash#key?` + explicit assignment so `nil` results are also cached.
- **Redundant rescue in `Backend::Tiktoken`** — removed a `rescue BackendError; raise`
  clause that caught and immediately re-raised without any transformation.
- **Thread-safe warn-once flag in `Backend::Approximate`** — the `@warned` flag is now
  guarded by a `Mutex` so concurrent callers cannot each emit the approximation warning.
- `Registry#build_entry` is now correctly `private` (it was an unintentionally exposed
  implementation detail).
- README wording now distinguishes between avoiding LLM API calls and first-use
  Hugging Face tokenizer downloads.

### Added
- GitHub Actions CI workflow (`.github/workflows/ci.yml`) — runs RSpec on Ruby 3.1–3.4
  for every push and pull request; includes an enforced RuboCop lint step.
- CI badge in README.
- README now documents that `HUGGING_FACE_HUB_TOKEN` is accepted as an alternative to
  `HF_TOKEN` for Hugging Face gated repository access.

### Changed
- RubyGems metadata now uses a distinct `source_code_uri`, eliminating the build-time
  duplicate-URI warning.

## [0.1.0] - 2026-06-05

- Initial release.
- `RubyLLM::Tokenizer.count`, `.analyze`, `.truncate` covering OpenAI (tiktoken)
  and open-weight (Hugging Face `tokenizers`) model families.
- Data-driven model registry (`lib/ruby_llm/tokenizer/models.yml`) with runtime
  `.register` for custom patterns.
- Opt-in approximate tokenizer for Anthropic Claude via
  `RubyLLM::Tokenizer.enable_claude_approximation!`.

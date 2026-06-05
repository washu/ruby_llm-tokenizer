# ruby_llm-tokenizer

[![CI](https://github.com/washu/ruby_llm-tokenizer/actions/workflows/ci.yml/badge.svg)](https://github.com/washu/ruby_llm-tokenizer/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/ruby_llm-tokenizer.svg)](https://rubygems.org/gems/ruby_llm-tokenizer)

Local, model-aware token counting for [ruby_llm](https://github.com/crmne/ruby_llm).
A pure-Ruby facade over Hugging Face [`tokenizers`](https://github.com/ankane/tokenizers-ruby) and OpenAI [`tiktoken_ruby`](https://github.com/IAPark/tiktoken_ruby) that maps model identifiers (`gpt-4o`, `llama-3`, `mistral`, ...) to the correct tokenizer and exposes a small API for counting, analyzing, and truncating text against a model's context window — without making an LLM API call.
No Rust toolchain required: cross-compiled binaries are inherited from the upstream gems.

## Installation

```bash
bundle add ruby_llm-tokenizer
```

Or:

```bash
gem install ruby_llm-tokenizer
```

Requires Ruby >= 3.1.

## Usage

```ruby
require "ruby_llm/tokenizer"

# Count tokens
RubyLLM::Tokenizer.count("Hello, world!", model: "gpt-4o")
# => 4

# Detailed breakdown
analysis = RubyLLM::Tokenizer.analyze("Hello, world!", model: "gpt-4o")
analysis.ids     # => [13225, 11, 2375, 0]
analysis.tokens  # => ["Hello", ",", " world", "!"]
analysis.count   # => 4
analysis.model   # => "tiktoken:o200k_base"

# Truncate to fit a context window
RubyLLM::Tokenizer.truncate(
  huge_log,
  max_tokens: 30_000,
  model: "gpt-4o",
  overflow: :truncate_left  # drop oldest content; default is :truncate_right
)

# Stream/Enumerable inputs work too
RubyLLM::Tokenizer.truncate(
  File.foreach("huge_log.txt"),
  max_tokens: 30_000,
  model: "gpt-4o",
  overflow: :truncate_left
)
```

For stream-like inputs, `truncate` accepts any `Enumerable` of chunks (for example
`File.foreach(...)`) and incrementally applies the same exact token-limit semantics as
string input. This avoids requiring callers to materialize the original source text up
front and avoids some duplicate tokenization work during truncation, though the
implementation may still retain the kept portion in memory.

## Supported model families (built-in)

| Family                                                    | Backend         | Encoding / Repo                          |
|-----------------------------------------------------------|-----------------|------------------------------------------|
| All OpenAI families (gpt-3.5/4/4o/4.1/4.5/5, o-series, gpt-oss, embeddings, ft:, legacy) | `tiktoken_auto` | resolved via `Tiktoken.encoding_for_model` |
| `llama-3` / `meta-llama`                                  | `hugging_face`  | `meta-llama/Meta-Llama-3-8B-Instruct`    |
| `mistral` / `mixtral`                                     | `hugging_face`  | `mistralai/Mistral-7B-Instruct-v0.2`     |
| `deepseek`                                                | `hugging_face`  | `deepseek-ai/DeepSeek-V2`                |
| `qwen`                                                    | `hugging_face`  | `Qwen/Qwen2.5-7B-Instruct`               |

OpenAI model resolution is delegated to `tiktoken_ruby` — new OpenAI models become available on `bundle update tiktoken_ruby` with no change to this gem. Override a specific model at runtime with `RubyLLM::Tokenizer.register(...)`.

OpenAI encodings are bundled with `tiktoken_ruby` (no network needed). Hugging Face `tokenizer.json` files are downloaded lazily on first use, then persisted under `cache_dir` for later offline reuse. Some HF repos (Llama 3, recent Mistral) are gated and require an HF token — see [Configuration](#configuration).

## Claude / Anthropic

Anthropic does not publish Claude's tokenizer. By default, `model: "claude-..."` raises `UnknownModelError`.

You can opt in to an approximate count (uses `o200k_base` as a stand-in; typically within 5–15% of the real number):

```ruby
RubyLLM::Tokenizer.enable_claude_approximation!
RubyLLM::Tokenizer.count("Hello", model: "claude-3-5-sonnet-20241022")
# warns once, then returns an approximate Integer
```

Do not use approximate counts to enforce hard context limits — leave headroom, or call Anthropic's `count_tokens` endpoint for exact numbers.

## Registering custom models

```ruby
RubyLLM::Tokenizer.register(
  match: /^my-finetuned-llama/,
  backend: :hugging_face,
  repo: "my-org/my-finetuned-llama-tokenizer"
)

RubyLLM::Tokenizer.register(
  match: "gpt-4o-2024-internal",
  backend: :tiktoken,
  encoding: "o200k_base"
)
```

User registrations take precedence over built-ins.

## Configuration

```ruby
RubyLLM::Tokenizer.configure do |c|
  c.cache_dir        = Pathname("/tmp/ruby_llm_tokenizer")  # default: ~/.cache/ruby_llm/tokenizer; stores downloaded HF tokenizers
  c.offline          = false                                # if true, never hits the HF Hub
  c.hf_token         = ENV["HF_TOKEN"]                      # also reads HUGGING_FACE_HUB_TOKEN
  c.approximate_warn = true                                 # warn on first approximate use
end
```

## Errors

| Class                                          | Raised when                                                 |
|------------------------------------------------|-------------------------------------------------------------|
| `RubyLLM::Tokenizer::UnknownModelError`        | No registered pattern matches the given model id            |
| `RubyLLM::Tokenizer::BackendError`             | Underlying tokenizer engine failed to load or encode        |
| `RubyLLM::Tokenizer::CacheError`               | `offline: true` and the local tokenizer.json is missing     |
| `RubyLLM::Tokenizer::ContextExceededError`     | Raised when a token count exceeds a defined limit (reserved for future use)  |


## Development

```bash
bin/setup
bundle exec rspec
bin/console
```

## Releasing

```bash
SKIP_PUSH=1 ./build_release.sh
./build_release.sh
GEM_HOST_OTP=123456 ./build_release.sh
```

- `SKIP_PUSH=1` builds the gem and verifies the release artifact without publishing.
- Running `./build_release.sh` normally builds and pushes, letting `gem push` prompt for MFA.
- `GEM_HOST_OTP=...` passes an explicit RubyGems OTP when you want a non-interactive push.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/washu/ruby_llm-tokenizer.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

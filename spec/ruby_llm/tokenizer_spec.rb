# frozen_string_literal: true

require "stringio"

RSpec.describe RubyLLM::Tokenizer do
  let(:gemini_model_file) { "/tmp/gemini-tokenizer.model" }

  it "has a version number" do
    expect(RubyLLM::Tokenizer::VERSION).to eq("0.1.1")
  end

  describe ".count" do
    it "counts tokens for an OpenAI gpt-4o model via tiktoken" do
      count = described_class.count("Hello, world!", model: "gpt-4o")
      expect(count).to be_a(Integer).and be > 0
    end

    it "counts tokens for an OpenAI gpt-3.5 model via tiktoken" do
      count = described_class.count("Hello, world!", model: "gpt-3.5-turbo")
      expect(count).to be_a(Integer).and be > 0
    end

    it "routes OpenAI families via tiktoken_auto delegation" do
      cases = {
        "gpt-5" => "o200k_base",
        "gpt-5-turbo" => "o200k_base",
        "gpt-4o" => "o200k_base",
        "gpt-4o-mini" => "o200k_base",
        "gpt-4.1" => "o200k_base",
        "gpt-4" => "cl100k_base",
        "gpt-3.5-turbo" => "cl100k_base",
        "gpt-oss-7b" => "o200k_harmony",
        "davinci-002" => "cl100k_base",
        "davinci" => "r50k_base",
        "ada" => "r50k_base",
        "text-davinci-001" => "r50k_base",
        "text-embedding-3-small" => "cl100k_base",
        "ft:gpt-4o-2024:my-org" => "cl100k_base",
        "o1-preview" => "o200k_base"
      }
      cases.each do |model, expected_encoding|
        result = described_class.analyze("Hello, world!", model: model)
        expect(result.model).to eq("tiktoken:#{expected_encoding}"),
                                "expected #{model} -> #{expected_encoding}, got #{result.model}"
      end
    end

    it "raises a helpful error for OpenAI-shaped models tiktoken_ruby doesn't know" do
      expect { described_class.count("hi", model: "gpt-9999-zzz") }
        .to raise_error(RubyLLM::Tokenizer::UnknownModelError, /tiktoken_ruby has no encoding mapping.*register/m)
    end

    it "still allows explicit override via register" do
      described_class.register(match: /^gpt-5$/, backend: :tiktoken, encoding: "o200k_harmony")
      result = described_class.analyze("hi", model: "gpt-5")
      expect(result.model).to eq("tiktoken:o200k_harmony")
    end

    it "produces different counts for different encodings on the same text" do
      o200k = described_class.count("Hello, world!", model: "gpt-4o")
      cl100k = described_class.count("Hello, world!", model: "gpt-4")
      # Same text, different BPE merges — counts can match but not guaranteed.
      expect([o200k, cl100k]).to all(be > 0)
    end

    it "raises UnknownModelError for an unmapped model" do
      expect { described_class.count("hi", model: "totally-made-up-model-xyz") }
        .to raise_error(RubyLLM::Tokenizer::UnknownModelError, /totally-made-up-model-xyz/)
    end

    it "raises UnknownModelError for Claude by default" do
      expect { described_class.count("hi", model: "claude-3-5-sonnet") }
        .to raise_error(RubyLLM::Tokenizer::UnknownModelError)
    end

    it "routes Gemini models through the SentencePiece backend when the model file env var is set" do
      sentencepiece = Module.new

      sentencepiece.const_set(
        :SentencePieceProcessor,
        Class.new do
          def initialize(model_file:)
            @model_file = model_file
          end

          def encode_as_ids(text)
            text.to_s.split(/\s+/).reject(&:empty?).each_index.map { |index| index + 1 }
          end

          def encode(text, out_type: nil)
            tokens = text.to_s.split(/\s+/).reject(&:empty?).map { |token| "▁#{token}" }
            out_type == "str" ? tokens : tokens.each_index.map { |index| index + 1 }
          end

          def decode(ids)
            Array(ids).map { |id| "piece#{id}" }.join(" ")
          end
        end
      )

      stub_const("SentencePiece", sentencepiece)
      old_value = ENV["GEMINI_TOKENIZER_MODEL_FILE"]
      begin
        ENV["GEMINI_TOKENIZER_MODEL_FILE"] = gemini_model_file

        result = described_class.analyze("hello gemini", model: "gemini-2.0-flash")

        expect(result.model).to eq("sentencepiece:#{gemini_model_file}")
        expect(result.ids).to eq([1, 2])
        expect(result.tokens).to eq(%w[▁hello ▁gemini])
      ensure
        ENV["GEMINI_TOKENIZER_MODEL_FILE"] = old_value
      end
    end
  end

  describe ".analyze" do
    it "returns an Analysis with ids and a token count" do
      result = described_class.analyze("Hello, world!", model: "gpt-4o")
      expect(result).to be_a(RubyLLM::Tokenizer::Analysis)
      expect(result.ids).to be_an(Array).and all(be_a(Integer))
      expect(result.count).to eq(result.ids.size)
      expect(result.model).to match(/^tiktoken:/)
    end
  end

  describe ".truncate" do
    let(:long) { "The quick brown fox jumps over the lazy dog. " * 50 }

    it "returns the original text if under the limit" do
      expect(described_class.truncate("hi", max_tokens: 100, model: "gpt-4o")).to eq("hi")
    end

    it "truncates from the right by default" do
      result = described_class.truncate(long, max_tokens: 5, model: "gpt-4o")
      expect(described_class.count(result, model: "gpt-4o")).to be <= 5
      expect(long).to start_with(result.split.first)
    end

    it "truncates from the left when requested" do
      result = described_class.truncate(long, max_tokens: 5, model: "gpt-4o", overflow: :truncate_left)
      expect(described_class.count(result, model: "gpt-4o")).to be <= 5
    end

    it "accepts an enumerable stream of chunks for right truncation" do
      chunks = long.scan(/.{1,37}/m)
      stream_input = chunks

      streamed = described_class.truncate(stream_input, max_tokens: 5, model: "gpt-4o")
      direct = described_class.truncate(long, max_tokens: 5, model: "gpt-4o")

      expect(streamed).to eq(direct)
    end

    it "returns the concatenated stream when an enumerable stays under the limit" do
      stream_input = ["Hello", ", ", "world!"]

      expect(described_class.truncate(stream_input, max_tokens: 100, model: "gpt-4o")).to eq("Hello, world!")
    end

    it "ignores nil and empty chunks in stream inputs" do
      stream_input = ["Hello", nil, "", ", ", "world!"]

      streamed = described_class.truncate(stream_input, max_tokens: 100, model: "gpt-4o")
      direct = described_class.truncate("Hello, world!", max_tokens: 100, model: "gpt-4o")

      expect(streamed).to eq(direct)
    end

    it "accepts an IO-like stream for left truncation" do
      stream = StringIO.new(long)
      stream_input = stream.each_line

      streamed = described_class.truncate(stream_input, max_tokens: 5, model: "gpt-4o", overflow: :truncate_left)
      direct = described_class.truncate(long, max_tokens: 5, model: "gpt-4o", overflow: :truncate_left)

      expect(streamed).to eq(direct)
    end

    it "returns an empty string when max_tokens is zero" do
      stream_input = long.each_line

      expect(described_class.truncate(long, max_tokens: 0, model: "gpt-4o")).to eq("")
      expect(described_class.truncate(stream_input, max_tokens: 0, model: "gpt-4o")).to eq("")
    end

    it "rejects negative max_tokens" do
      expect { described_class.truncate(long, max_tokens: -1, model: "gpt-4o") }
        .to raise_error(ArgumentError, /max_tokens must be >= 0/)
    end

    it "rejects non-integer max_tokens" do
      invalid_max_tokens = 3.5

      expect { described_class.truncate(long, max_tokens: invalid_max_tokens, model: "gpt-4o") }
        .to raise_error(ArgumentError, /max_tokens must be an Integer/)
    end

    it "rejects unknown overflow strategies" do
      expect { described_class.truncate(long, max_tokens: 5, model: "gpt-4o", overflow: :bogus) }
        .to raise_error(ArgumentError, /Unknown overflow strategy/)
    end
  end

  describe ".register" do
    it "allows custom model patterns and they win over built-ins" do
      described_class.register(match: /^gpt-4o$/, backend: :tiktoken, encoding: "cl100k_base")
      result = described_class.analyze("hi", model: "gpt-4o")
      expect(result.model).to eq("tiktoken:cl100k_base")
    end
  end

  describe ".enable_claude_approximation!" do
    it "routes claude models to the approximate backend" do
      described_class.configure { |c| c.approximate_warn = false }
      described_class.enable_claude_approximation!
      result = described_class.analyze("hello", model: "claude-3-5-sonnet-20241022")
      expect(result.model).to eq("approximate:o200k_base")
      expect(result.count).to be > 0
    end

    it "warns once when approximate_warn is enabled" do
      described_class.configure { |c| c.approximate_warn = true }
      described_class.enable_claude_approximation!
      expect(Kernel).to receive(:warn).with(/approximate tokenizer/).once
      described_class.count("hello", model: "claude-3-5-sonnet")
      described_class.count("hello again", model: "claude-3-5-sonnet")
    end
  end

  describe ".configure" do
    it "yields a Configuration" do
      described_class.configure do |c|
        expect(c).to be_a(RubyLLM::Tokenizer::Configuration)
        c.offline = true
      end
      expect(described_class.configuration.offline).to be(true)
    end
  end
end

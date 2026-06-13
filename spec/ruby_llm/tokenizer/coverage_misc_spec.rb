# frozen_string_literal: true

# Small targeted specs covering edge-case guard rails and reserved error paths
# that the main suite doesn't naturally hit.

RSpec.describe "edge cases" do
  describe RubyLLM::Tokenizer::ContextExceededError do
    it "stores token_count, limit, and model" do
      err = described_class.new("too big", token_count: 1500, limit: 1000, model: "gpt-4o")
      expect(err.message).to eq("too big")
      expect(err.token_count).to eq(1500)
      expect(err.limit).to eq(1000)
      expect(err.model).to eq("gpt-4o")
    end
  end

  describe RubyLLM::Tokenizer::Backend::Base do
    subject(:base) { described_class.new }

    it "raises NotImplementedError on #encode" do
      expect { base.encode("x") }.to raise_error(NotImplementedError, /#encode must be implemented/)
    end

    it "raises NotImplementedError on #decode" do
      expect { base.decode([1]) }.to raise_error(NotImplementedError, /#decode must be implemented/)
    end

    it "derives a default identifier from the class name" do
      stub_const("RubyLLM::Tokenizer::Backend::Marvin", Class.new(described_class))
      expect(RubyLLM::Tokenizer::Backend::Marvin.new.identifier).to eq("marvin")
    end

    it "rejects non-integer max_tokens in #truncate" do
      expect { base.truncate("x", max_tokens: 1.5) }
        .to raise_error(ArgumentError, /max_tokens must be an Integer/)
    end

    it "rejects negative max_tokens in #truncate" do
      expect { base.truncate("x", max_tokens: -1) }
        .to raise_error(ArgumentError, /max_tokens must be >= 0/)
    end

    it "returns an empty string when max_tokens is zero" do
      expect(base.truncate("anything", max_tokens: 0)).to eq("")
    end

    it "ignores nil and empty chunks before invoking encode" do
      stub_backend = Class.new(described_class) do
        attr_reader :seen

        def initialize
          super
          @seen = []
        end

        def encode(text)
          @seen << text
          text.bytes
        end

        def decode(ids)
          ids.pack("C*")
        end
      end

      backend = stub_backend.new
      result = backend.truncate([nil, "", "abc"], max_tokens: 10)

      expect(result).to eq("abc")
      expect(backend.seen).to eq(["abc"])
    end

    it "leaves a left-truncation stream untouched when it stays under the limit" do
      stub_backend = Class.new(described_class) do
        def encode(text)
          text.bytes
        end

        def decode(ids)
          ids.pack("C*")
        end
      end

      backend = stub_backend.new
      expect(backend.truncate(["Hello", " world"], max_tokens: 100, overflow: :truncate_left)).to eq("Hello world")
    end
  end

  describe RubyLLM::Tokenizer::Registry::Entry do
    it "returns false when match is neither Regexp nor String" do
      entry = described_class.new(match: 42, backend: :tiktoken, options: {})
      expect(entry.matches?("anything")).to be(false)
    end
  end
end

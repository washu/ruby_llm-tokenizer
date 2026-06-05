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
  end

  describe RubyLLM::Tokenizer::Backend::Tiktoken do
    it "raises BackendError for an unknown encoding name" do
      expect { described_class.new(encoding: "no_such_encoding_xyz") }
        .to raise_error(RubyLLM::Tokenizer::BackendError, /Unknown tiktoken encoding.*no_such_encoding_xyz/)
    end

    it "wraps unexpected Tiktoken errors in BackendError" do
      allow(Tiktoken).to receive(:get_encoding).and_raise(StandardError, "kaboom")
      expect { described_class.new(encoding: "cl100k_base") }
        .to raise_error(RubyLLM::Tokenizer::BackendError, /Failed to load.*kaboom/)
    end
  end

  describe RubyLLM::Tokenizer::Registry::Entry do
    it "returns false when match is neither Regexp nor String" do
      entry = described_class.new(match: 42, backend: :tiktoken, options: {})
      expect(entry.matches?("anything")).to be(false)
    end
  end
end

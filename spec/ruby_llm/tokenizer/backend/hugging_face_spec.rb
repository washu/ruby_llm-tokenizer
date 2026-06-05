# frozen_string_literal: true

require "tmpdir"

RSpec.describe RubyLLM::Tokenizer::Backend::HuggingFace do
  let(:fixtures_root) { Pathname.new(File.expand_path("../../../fixtures", __dir__)) }
  let(:fake_tokenizer) { Tokenizers.from_file(fixtures_root.join("tiny-tokenizer", "tokenizer.json").to_s) }

  describe "offline mode (from_file)" do
    before do
      RubyLLM::Tokenizer.configure do |c|
        c.offline = true
        c.cache_dir = fixtures_root
      end
      RubyLLM::Tokenizer.register(
        match: /^tiny-/,
        backend: :hugging_face,
        repo: "tiny-tokenizer"
      )
    end

    it "encodes via the on-disk tokenizer.json" do
      result = RubyLLM::Tokenizer.analyze("Hello, world!", model: "tiny-test")
      expect(result.ids).to eq([1, 13, 2, 14])
      expect(result.tokens).to eq(%w[hello , world !])
      expect(result.model).to eq("hugging_face:tiny-tokenizer")
    end

    it "counts tokens" do
      expect(RubyLLM::Tokenizer.count("the lazy dog", model: "tiny-test")).to eq(3)
    end

    it "truncates from the right" do
      result = RubyLLM::Tokenizer.truncate(
        "the quick brown fox jumps over the lazy dog",
        max_tokens: 4,
        model: "tiny-test"
      )
      expect(RubyLLM::Tokenizer.count(result, model: "tiny-test")).to eq(4)
    end

    it "raises CacheError when the tokenizer.json is missing" do
      RubyLLM::Tokenizer.register(
        match: "nope-model",
        backend: :hugging_face,
        repo: "does-not-exist"
      )
      expect { RubyLLM::Tokenizer.count("hi", model: "nope-model") }
        .to raise_error(RubyLLM::Tokenizer::CacheError, /not cached/)
    end
  end

  describe "online mode (from_pretrained)" do
    before do
      RubyLLM::Tokenizer.configure do |c|
        c.offline = false
        c.hf_token = "hf_test_token"
      end
      RubyLLM::Tokenizer.register(
        match: "online-model",
        backend: :hugging_face,
        repo: "fake-org/fake-repo",
        revision: "v1.2.3"
      )
    end

    it "calls Tokenizers.from_pretrained with the configured auth_token and revision" do
      expect(Tokenizers).to receive(:from_pretrained)
        .with("fake-org/fake-repo", auth_token: "hf_test_token", revision: "v1.2.3")
        .and_return(fake_tokenizer)

      result = RubyLLM::Tokenizer.analyze("hello", model: "online-model")
      expect(result.ids).to eq([1])
      expect(result.model).to eq("hugging_face:fake-org/fake-repo@v1.2.3")
    end

    it "omits auth_token when no HF token is configured" do
      RubyLLM::Tokenizer.configure { |c| c.hf_token = nil }
      expect(Tokenizers).to receive(:from_pretrained)
        .with("fake-org/fake-repo", revision: "v1.2.3")
        .and_return(fake_tokenizer)

      RubyLLM::Tokenizer.count("hello", model: "online-model")
    end

    it "wraps unexpected errors in BackendError" do
      allow(Tokenizers).to receive(:from_pretrained).and_raise(StandardError, "boom")

      expect { RubyLLM::Tokenizer.count("hi", model: "online-model") }
        .to raise_error(RubyLLM::Tokenizer::BackendError, %r{fake-org/fake-repo.*boom})
    end

    it "persists the downloaded tokenizer into cache_dir so offline mode can reuse it" do
      Dir.mktmpdir("ruby-llm-tokenizer-cache") do |dir|
        cache_dir = Pathname(dir)

        RubyLLM::Tokenizer.configure do |c|
          c.offline = false
          c.cache_dir = cache_dir
          c.hf_token = nil
        end

        expect(Tokenizers).to receive(:from_pretrained)
          .with("fake-org/fake-repo", revision: "v1.2.3")
          .and_return(fake_tokenizer)

        online_result = RubyLLM::Tokenizer.analyze("hello", model: "online-model")
        expect(online_result.ids).to eq([1])

        cached_path = cache_dir.join("fake-org-fake-repo", "tokenizer.json")
        expect(cached_path).to exist

        RubyLLM::Tokenizer.reset!
        RubyLLM::Tokenizer.configure do |c|
          c.offline = true
          c.cache_dir = cache_dir
        end
        RubyLLM::Tokenizer.register(
          match: "online-model",
          backend: :hugging_face,
          repo: "fake-org/fake-repo",
          revision: "v1.2.3"
        )

        offline_result = RubyLLM::Tokenizer.analyze("hello", model: "online-model")
        expect(offline_result.ids).to eq([1])
        expect(offline_result.model).to eq("hugging_face:fake-org/fake-repo@v1.2.3")
      end
    end
  end
end

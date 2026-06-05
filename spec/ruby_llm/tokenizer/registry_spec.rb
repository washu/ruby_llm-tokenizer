# frozen_string_literal: true

RSpec.describe RubyLLM::Tokenizer::Registry do
  subject(:registry) { described_class.new }

  describe "#register and #resolve" do
    it "matches by literal string" do
      registry.register(match: "exact-model", backend: :tiktoken, encoding: "cl100k_base")
      expect(registry.resolve("exact-model")).to be_a(RubyLLM::Tokenizer::Backend::Tiktoken)
      expect(registry.resolve("exact-modeloid")).to be_nil
    end

    it "matches by Regexp" do
      registry.register(match: /^foo-/, backend: :tiktoken, encoding: "cl100k_base")
      expect(registry.resolve("foo-bar")).not_to be_nil
      expect(registry.resolve("baz")).to be_nil
    end

    it "raises BackendError for an unknown backend symbol" do
      registry.register(match: "x", backend: :nonsense)
      expect { registry.resolve("x") }.to raise_error(RubyLLM::Tokenizer::BackendError, /nonsense/)
    end
  end

  describe "#entries and #clear" do
    it "exposes a copy of entries" do
      registry.register(match: "a", backend: :tiktoken, encoding: "cl100k_base")
      expect(registry.entries.size).to eq(1)
      registry.entries.clear
      expect(registry.entries.size).to eq(1), "entries should return a dup, not the internal array"
    end

    it "clears all entries" do
      registry.register(match: "a", backend: :tiktoken, encoding: "cl100k_base")
      registry.clear
      expect(registry.entries).to be_empty
      expect(registry.resolve("a")).to be_nil
    end
  end

  describe ".parse_match" do
    it "parses /regex/ syntax with flags" do
      r = described_class.parse_match("/^foo/i")
      expect(r).to be_a(Regexp)
      expect(r).to be_an_instance_of(Regexp)
      expect(r.match?("FOO-bar")).to be(true)
    end

    it "returns a literal string when not in /regex/ form" do
      expect(described_class.parse_match("plain-string")).to eq("plain-string")
    end

    it "supports multiline and extended flags" do
      multiline = described_class.parse_match("/a.b/m")
      extended = described_class.parse_match("/a b/x")

      expect(multiline).to be_an_instance_of(Regexp)
      expect(extended).to be_an_instance_of(Regexp)
      expect(multiline.options & Regexp::MULTILINE).not_to eq(0)
      expect(extended.options & Regexp::EXTENDED).not_to eq(0)
    end
  end

  describe "default registry loading" do
    it "raises a helpful error for malformed matcher values" do
      bad_defaults = [{ "match" => 123, "backend" => "tiktoken", "encoding" => "cl100k_base" }]
      allow(YAML).to receive(:load_file).and_return(bad_defaults)

      expect { registry.load_defaults_from("ignored.yml") }
        .to raise_error(RubyLLM::Tokenizer::BackendError, /Invalid model matcher/)
    end

    it "raises a helpful error for malformed backend values" do
      bad_defaults = [{ "match" => "demo-model", "backend" => 123, "encoding" => "cl100k_base" }]
      allow(YAML).to receive(:load_file).and_return(bad_defaults)

      expect { registry.load_defaults_from("ignored.yml") }
        .to raise_error(RubyLLM::Tokenizer::BackendError, /Invalid backend identifier/)
    end
  end
end

# frozen_string_literal: true

RSpec.describe RubyLLM::Tokenizer::Backend::Tiktoken do
  it "raises BackendError for an unknown encoding name" do
    expect { described_class.new(encoding: "no_such_encoding_xyz") }
      .to raise_error(RubyLLM::Tokenizer::BackendError, /Unknown tiktoken encoding.*no_such_encoding_xyz/)
  end

  it "wraps unexpected Tiktoken errors in BackendError" do
    allow(Tiktoken).to receive(:get_encoding).and_raise(StandardError, "kaboom")
    expect { described_class.new(encoding: "cl100k_base") }
      .to raise_error(RubyLLM::Tokenizer::BackendError, /Failed to load.*kaboom/)
  end

  it "encodes, decodes, and identifies the encoding" do
    backend = described_class.new(encoding: "cl100k_base")

    expect(backend.identifier).to eq("tiktoken:cl100k_base")
    expect(backend.count("hello world")).to be > 0
    expect(backend.decode(backend.encode("hello world"))).to eq("hello world")
  end
end


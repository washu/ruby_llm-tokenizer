# frozen_string_literal: true

RSpec.describe RubyLLM::Tokenizer::Backend::SentencePiece do
  let(:fixtures_root) { Pathname.new(__dir__).parent.parent.parent.join("fixtures") }
  # Upstream fixture from google/sentencepiece: data/test_oss_model.model
  let(:model_file) { fixtures_root.join("sentencepiece", "test_oss_model.model").to_s }

  def sentencepiece_available?
    require "sentencepiece"
    true
  rescue LoadError
    false
  end

  it "uses a real SentencePiece model fixture when the native library is available" do
    skip "sentencepiece gem/native library unavailable" unless sentencepiece_available?

    backend = described_class.new(model_file: model_file)
    processor = SentencePiece::SentencePieceProcessor.allocate
    processor.load(model_file)

    text = "This is a small SentencePiece fixture."
    ids = processor.encode_as_ids(text)

    expect(backend.identifier).to eq("sentencepiece:#{model_file}")
    expect(backend.encode(text)).to eq(ids)
    expect(backend.decode(ids)).to eq(processor.decode(ids))
    expect(backend.analyze(text).tokens).to eq(processor.encode(text, out_type: "str"))

    truncated = backend.truncate(text, max_tokens: 3)
    expect(backend.count(truncated)).to be <= 3
  end

  it "raises a helpful error when no model file is provided" do
    expect { described_class.new }.to raise_error(
      RubyLLM::Tokenizer::BackendError,
      /requires :model_file or :model_file_env/
    )
  end

  it "raises a helpful error when model_file_env is set but the env var is missing" do
    expect { described_class.new(model_file_env: "SENTENCEPIECE_TEST_MODEL_FILE") }.to raise_error(
      RubyLLM::Tokenizer::BackendError,
      /requires :model_file or :model_file_env/
    )
  end

  it "raises a helpful error when the sentencepiece library cannot be required" do
    sentencepiece = Module.new
    original_const_get = Module.instance_method(:const_get)
    sentencepiece.define_singleton_method(:const_get) do |name, *args|
      raise NameError, "missing processor" if name == :SentencePieceProcessor

      original_const_get.bind(self).call(name, *args)
    end
    stub_const("SentencePiece", sentencepiece)

    original_require = Kernel.instance_method(:require)
    Kernel.define_method(:require) do |name|
      raise LoadError, "cannot load such file -- sentencepiece" if name == "sentencepiece"

      original_require.bind(self).call(name)
    end

    expect { described_class.new(model_file: model_file) }
      .to raise_error(RubyLLM::Tokenizer::BackendError, /compiled SentencePiece library/i)
  ensure
    Kernel.define_method(:require, original_require)
  end

  it "raises a helpful error when the processor constant is still missing after require" do
    stub_const("SentencePiece", Module.new)
    allow(Kernel).to receive(:require).with("sentencepiece").and_return(true)

    expect { described_class.new(model_file: model_file) }
      .to raise_error(RubyLLM::Tokenizer::BackendError, /SentencePieceProcessor to be available/i)
  end
end


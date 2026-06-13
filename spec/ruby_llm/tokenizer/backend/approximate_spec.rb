# frozen_string_literal: true

RSpec.describe RubyLLM::Tokenizer::Backend::Approximate do
  it "delegates to tiktoken and uses the approximate identifier" do
    described_class.new(encoding: "cl100k_base")
    RubyLLM::Tokenizer.configure { |c| c.approximate_warn = false }

    backend = described_class.new(encoding: "cl100k_base")

    expect(backend.identifier).to eq("approximate:cl100k_base")
    expect(backend.count("hello world")).to be > 0
  end

  it "warns once and exercises the synchronized early-return path" do
    RubyLLM::Tokenizer.configure { |c| c.approximate_warn = true }

    backend = described_class.new(encoding: "cl100k_base")
    fake_mutex = Class.new do
      def initialize(owner)
        @owner = owner
      end

      def synchronize
        @owner.instance_variable_set(:@warned, true)
        yield
      end
    end.new(backend)

    backend.instance_variable_set(:@warned, false)
    backend.instance_variable_set(:@warn_mutex, fake_mutex)

    expect(Kernel).not_to receive(:warn)
    expect(backend.count("hello world")).to be > 0
  end
end

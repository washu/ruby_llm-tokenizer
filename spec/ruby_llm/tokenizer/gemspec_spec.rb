# frozen_string_literal: true

RSpec.describe "ruby_llm-tokenizer.gemspec" do
  let(:gemspec_path) { File.expand_path("../../../ruby_llm-tokenizer.gemspec", __dir__) }
  let(:spec) { Gem::Specification.load(gemspec_path) }

  it "includes a post-install notice about SentencePiece native library requirements" do
    expect(spec.post_install_message).to include("SentencePiece")
    expect(spec.post_install_message).to include("brew install sentencepiece")
    expect(spec.post_install_message).to include("libsentencepiece-dev")
  end
end



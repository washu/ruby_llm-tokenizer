# frozen_string_literal: true

RSpec.describe RubyLLM::Tokenizer::Analysis do
  subject(:analysis) { described_class.new(tokens: %w[a b c], ids: [1, 2, 3], model: "x:y") }

  it "exposes count as ids.size" do
    expect(analysis.count).to eq(3)
  end

  it "serialises to a hash including count" do
    expect(analysis.to_h).to eq(tokens: %w[a b c], ids: [1, 2, 3], model: "x:y", count: 3)
  end
end

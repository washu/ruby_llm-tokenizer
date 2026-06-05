# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/spec/"
  enable_coverage :branch
end

require "ruby_llm/tokenizer"
require "webmock/rspec"

RSpec.configure do |config|
  config.example_status_persistence_file_path = ".rspec_status"
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Reset the singleton registry/configuration between examples so tests don't
  # leak state through RubyLLM::Tokenizer.register or .configure.
  config.before(:each) { RubyLLM::Tokenizer.reset! }

  # Block real HTTP by default; opt back in per-example with WebMock.disable_net_connect!(allow_localhost: true)
  WebMock.disable_net_connect!
end

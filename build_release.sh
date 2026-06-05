#!/bin/bash
set -e

# Extract version from version.rb
VERSION=$(ruby -r ./lib/ruby_llm/tokenizerversion.rb -e "puts RubyLLM::Tokenizer::VERSION")

echo "Building gem version ${VERSION}..."
gem build ruby_llm-tokenizer.gemspec

echo "Pushing to RubyGems..."
gem push ruby_llm-tokenizer-${VERSION}.gem

echo "Done!"

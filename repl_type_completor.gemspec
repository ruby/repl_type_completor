# frozen_string_literal: true

require_relative "lib/repl_type_completor/version"

Gem::Specification.new do |spec|
  spec.name = "repl_type_completor"
  spec.version = ReplTypeCompletor::VERSION
  spec.authors = ["tompng"]
  spec.email = ["tomoyapenguin@gmail.com"]

  spec.summary = "Type based completion for REPL."
  spec.description = "Type based completion for REPL."
  spec.homepage = "https://github.com/ruby/repl_type_completor"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "TODO: Set to your gem server 'https://example.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/ruby/repl_type_completor"
  spec.metadata["documentation_uri"] = spec.homepage

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (File.expand_path(f) == __FILE__) || f.start_with?(*%w[bin/ test/ spec/ features/ .git .circleci appveyor])
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "prism", ">= 0.18.0"
  spec.add_dependency "rbs", ">= 2.7.0"
end

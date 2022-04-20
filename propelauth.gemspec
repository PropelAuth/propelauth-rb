# frozen_string_literal: true

require_relative "lib/propelauth/version"

Gem::Specification.new do |spec|
  spec.name = "propelauth"
  spec.version = PropelAuth::VERSION
  spec.authors = ["Andrew Israel"]
  spec.email = ["support@propelauth.com"]

  spec.summary = "A ruby gem for managing authentication, backed by PropelAuth"
  spec.homepage = "https://github.com/PropelAuth/propelauth-rb"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 2.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/PropelAuth/propelauth-rb"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(__dir__) do
    `git ls-files -z`.split("\x0").reject do |f|
      (f == __FILE__) || f.match(%r{\A(?:(?:bin|test|spec|features)/|\.(?:git|travis|circleci)|appveyor)})
    end
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "jwt", "~> 2.3"
  spec.add_dependency "faraday", '~> 2.0'
  spec.add_dependency "railties", ">= 4.1.0"

end

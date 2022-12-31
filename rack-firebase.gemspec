require File.expand_path("lib/rack/firebase/version", __dir__)

Gem::Specification.new do |s|
  s.name = "rack-firebase"
  s.version = Rack::Firebase::VERSION
  s.author = "Laura Mosher"
  s.email = "laura@mosher.tech"

  s.summary = "Verify Firebase ID Tokens in Middleware"
  s.description = "A simple, lightweight Rack middleware to verify Firebase tokens."
  s.homepage = "https://github.com/lauramosher/rack-firebase"
  s.license = "MIT"

  s.files = Dir["lib/**/*.rb"] + %w[LICENSE README.md]
  s.require_paths = ["lib"]

  s.add_dependency "rack", ">=2.0"
  s.add_dependency "jwt", "~> 2.6"
  s.add_dependency "openssl", ">= 2.0"

  s.add_development_dependency "rspec", "~> 2.14"
  s.add_development_dependency "rack-test", "~> 2.0.2"
  s.add_development_dependency "simplecov", "~> 0.22.0"
  s.add_development_dependency "standard", "~> 1.9.0"
end

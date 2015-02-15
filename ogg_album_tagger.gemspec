# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ogg_album_tagger/version'

Gem::Specification.new do |spec|
  spec.name          = "ogg_album_tagger"
  spec.version       = OggAlbumTagger::VERSION
  spec.authors       = ["Cyrille Faucheux"]
  spec.email         = ["cyrille.faucheux@gmail.com"]
  spec.summary       = %q{Interactive edition of ogg tags in an album or a compilation.}
  spec.homepage      = ""
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.add_runtime_dependency "exiftool", [">= 0.6"]
  spec.add_runtime_dependency "taglib-ruby", [">= 0.7"]
end

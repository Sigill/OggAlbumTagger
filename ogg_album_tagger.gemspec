# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'ogg_album_tagger/version'

Gem::Specification.new do |spec|
  spec.name          = "ogg_album_tagger"
  spec.version       = OggAlbumTagger::VERSION
  spec.authors       = ["Cyrille Faucheux"]
  spec.email         = ["cyrille.faucheux@gmail.com"]
  spec.summary       = "Interactive edition of ogg tags with support for whole albums."
  spec.homepage      = "https://github.com/Sigill/OggAlbumTagger"
  spec.license       = "MIT"

  spec.files         = %w{bin/ogg-album-tagger
                          lib/ogg_album_tagger/cli.rb
                          lib/ogg_album_tagger/exceptions.rb
                          lib/ogg_album_tagger/library.rb
                          lib/ogg_album_tagger/ogg_file.rb
                          lib/ogg_album_tagger/picture.rb
                          lib/ogg_album_tagger/tag_container.rb
                          lib/ogg_album_tagger/version.rb}
  spec.executables   = %w{ogg-album-tagger}
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "minitest", "~> 5.11"
  spec.add_development_dependency "m", "~> 1.5"

  spec.add_runtime_dependency "exiftool", ["~> 0.6"]
  spec.add_runtime_dependency "taglib-ruby", ["~> 0.7"]
end

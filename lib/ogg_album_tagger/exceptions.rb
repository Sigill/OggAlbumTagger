module OggAlbumTagger

class Error < ::StandardError; end

class SystemError < OggAlbumTagger::Error; end
class ArgumentError < OggAlbumTagger::Error; end
class MetadataError < OggAlbumTagger::Error; end

end

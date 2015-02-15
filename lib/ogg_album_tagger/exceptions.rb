module OggAlbumTagger

class Error < ::StandardError; end

class SystemError < Error; end
class ArgumentError < Error; end
class MetadataError < Error; end

end

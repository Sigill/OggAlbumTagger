require 'ogg_album_tagger/library'

# Library with some helper methods to easily write unit tests.
class TestingLibrary < OggAlbumTagger::Library
    attr_reader :files

    # For test purpose, overriden to do nothing.
    def write; end

    # For test purpose, overriden to do nothing.
    def rename(oldpath, newpath); end

    # Helper method to apply some modification to a subset of the library.
    # Applies the specified, yields +self+ then applies another selection.
    # - selection:: The selection to apply before yielding.
    # - after:: The selection to apply before returning.
    def apply(selection, after = %w{all})
        select(selection)
        yield(self)
        select(after)

        self
    end

    # Override the original select() method to allow the selection to be specified with a single value,
    # which is automatically transformed to an array of string as expected by the original select() method.
    def select(args)
        args = args.to_s unless args.is_a? String or args.is_a? Array
        args = [args] unless args.is_a? Array
        super(args)
    end

    # Helper method to select all items in the library.
    def select_all
        select %w{all}
    end
end
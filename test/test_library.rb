require 'minitest/autorun'
require 'set'
require 'ogg_album_tagger/tag_container'
require 'ogg_album_tagger/library'
require 'fileutils'

# Mock of a TagContainer that can be built manually instead of reading an Ogg file.
class FakeOgg < OggAlbumTagger::TagContainer
    # Allow to build a TagContainer using the following syntax:
    #
    # <tt>t = FakeOgg.new artist: "Alice", genre: %w{Pop Rock}, tracknumber: 1, ...</tt>
    # The values associated to a tag are automatically casted to a String.
    # Single values are treated as an array of one value.
    def initialize tags = {}
        @hash = Hash.new

        tags.each { |tag, values|
            prepare_tag(tag.to_s.upcase)
            values = [values] unless values.is_a? Array
            values.each { |value| @hash[tag.to_s.upcase].add(value.to_s) }
        }
    end

    # For test purpose, overriden to do nothing.
    def write(file) end
end

# Helper method that build a FakeOgg object from the specified tags.
def ogg(tags = {})
    FakeOgg.new(tags)
end

# Library with some helper methods to easily write unit tests.
class FakeLibrary < OggAlbumTagger::Library
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

# Helper method to build a mocked library.
def library(dir, tracks = {})
    FakeLibrary.new(dir, tracks)
end

# Helper function to create a test directory containing blank ogg files.
# dir:: The directory where the files will be created. It must exists.
# relpaths:: the relative paths (wrt dir) of the ogg files.
#
# Returns a hash mapping the relative paths to the associated TagContainers.
def make_fs_library(dir, *relpaths)
    relpaths.map { |relpath|
        path = dir + relpath
        FileUtils.cp("test/data/empty.ogg", path.to_s)

        [relpath, OggAlbumTagger::TagContainer.new(path)]
    }.to_h
end

module Minitest::Assertions
    # Verify that check() does not raise a MetadataError when called on the specified library.
    #
    # lib:: The library being checked.
    def assert_valid_library(lib)
        begin
            lib.check()
        rescue Exception => e
            m = "This library was supposed to be valid:\n#{mu_pp(lib.summary)}\nbut this exception was raised: #{e.message}"
            flunk m
        end
    end

    # Verify that a MetadataError exception is raised when check() is called on a invalid library.
    #
    # lib:: The library being checked.
    # expected_msg:: The expected message of the exception.
    def assert_raises_metadata_error(lib, expected_msg)
        m = "This following library was supposed to throw this MetadataError: \"#{expected_msg}\"\n#{mu_pp(lib.summary)}"
        e = assert_raises(OggAlbumTagger::MetadataError, m) { lib.check() }
        assert_equal expected_msg, e.message
    end

    # Shorthand method to check the summary of the specified library.
    def assert_summary(lib, exp = {})
        assert_equal exp, lib.summary
    end

    # Verify that the tag constraints related to all types of library are respected.
    #
    # This assertion takes a block that returns a valid library and verify that the following
    # changes will get check() to raise a MetadataError exception:
    # - the _ARTIST_, _TITLE_ or _DATE_ tag is missing.
    # - the _ARTIST_, _TITLE_, _DATE_, _ALBUM_, _ALBUMDATE_, _ARTISTALBUM_, _TRACKNUMBER_ or _DISCNUMBER_ tag has multiple values.
    # - the _DISCNUMBER_ or _TRACKNUMBER_ tag has a non-numerical value.
    # - the _DATE_ or _ALBUMDATE_ tag does not represent a valid date.
    def assert_basic_library_checks
        %w{ARTIST TITLE DATE}.each { |t|
            l = yield.apply(1, %w{1 3}) { |l| l.rm_tag(t) }
            assert_raises_metadata_error(l, "The #{t} tag must be used once per track.")
        }

        %w{ARTIST TITLE DATE ALBUM ALBUMDATE ARTISTALBUM TRACKNUMBER DISCNUMBER}.each { |t|
            l = yield.apply(1, %w{1 3}) { |l| l.set_tag(t, "one", "two") }
            assert_raises_metadata_error(l, "The #{t} tag must not appear more than once per track.")
        }

        %w{DISCNUMBER TRACKNUMBER}.each { |t|
            l = yield.apply(1, %w{1 3}) { |l| l.set_tag(t, "foo") }
            assert_raises_metadata_error(l, "If used, the #{t} tag must have a numeric value.")
        }

        %w{DATE ALBUMDATE}.each { |t|
            l = yield.apply(1, %w{1 3}) { |l| l.set_tag(t, "20000") }
            assert_raises_metadata_error(l, "If used, the #{t} tag must be a valid year.")
        }
    end

    # Verify that the tag constraints specific to "group" library (album, compilation, best-of) are respected.
    #
    # This assertion takes a block that returns a valid library and verify that the following
    # changes will get check() to raise a MetadataError exception:
    # - the _TRACKNUMBER_ tag is missing.
    # - the _ALBUM_ tag does not have a unique value across the tracks.
    def assert_group_library_checks
        l = yield.apply(1, %w{1 3}) { |l| l.rm_tag("TRACKNUMBER") }
        assert_raises_metadata_error(l, "The TRACKNUMBER tag must be used once per track.")

        l = yield.apply(1, %w{1 3}) { |l| l.set_tag("ALBUM", "another") }
        assert_raises_metadata_error(l, "The ALBUM tag must have a single and unique value among all songs.")
    end
end

# Thests for the Library class.
class LibraryTest < Minitest::Test
    DIR = Pathname.new("/foo/bar").freeze
    A = (DIR + "a.ogg").freeze
    B = (DIR + "b.ogg").freeze
    C = (DIR + "c.ogg").freeze
    D = (DIR + "d.ogg").freeze


    # Test the select() method.
    def test_select
        lib = library nil, A => ogg(), B => ogg(), C => ogg(), D => ogg()
        assert_equal Set[A, B, C, D], lib.selected_files

        lib.select(%w{1})
        assert_equal Set[A], lib.selected_files

        lib.select(%w{+2})
        assert_equal Set[A, B], lib.selected_files

        lib.select(%w{-2})
        assert_equal Set[A], lib.selected_files

        lib.select(%w{3-4})
        assert_equal Set[C, D], lib.selected_files

        lib.select(%w{1 2})
        assert_equal Set[A, B], lib.selected_files

        lib.select(%w{2 3-4})
        assert_equal Set[B, C, D], lib.selected_files

        lib.select(%w{all})
        assert_equal Set[A, B, C, D], lib.selected_files

        lib.select(%w{-2-3})
        assert_equal Set[A, D], lib.selected_files

        lib.select(%w{+2-3})
        assert_equal Set[A, B, C, D], lib.selected_files

        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{+1 all}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{foo}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{0}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{5}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{+bar}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{+0}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{-5}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{4-2}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{+1 2}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.select(%w{+1 2-3}) }
    end

    # Test the tags_used() method.
    def test_tags_used
        lib = library nil
        assert_equal [] , lib.tags_used

        lib = library nil, A => ogg(foo: %w{bar}), B => ogg(baz: %w{qux})
        assert_equal %w{foo baz}, lib.tags_used

        lib = library nil, A => ogg(foo: %w{bar}), B => ogg(foo: %w{baz})
        assert_equal %w{foo}, lib.tags_used
    end

    # Test the summary() method.
    def test_summary
        lib = library nil, A => ogg(foo: %w{bar}), B => ogg(baz: %w{qux quux})
        assert_summary lib, "FOO" => {0 => %w{bar}}, "BAZ" => {1 => %w{quux qux}}

        assert_equal({"FOO" => {0 => %w{bar}}}, lib.summary("FOO"))

        lib.select(2)

        assert_equal({}, lib.tag_summary("FOO"))

        lib.select_all()

        assert_equal({}, lib.summary("BAR"))

        assert_equal({0 => %w{bar}}, lib.tag_summary("FOO"))
        assert_equal({}, lib.tag_summary("BAR"))
    end

    # Test the tag_summary() method.
    def test_tag_summary
        lib = library nil, A => ogg(foo: %w{bar}), B => ogg(foo: %w{corge}, baz: %w{qux quux})
        assert_equal({0 => ["bar"], 1 => ["corge"]}, lib.tag_summary("FOO"))
    end

    # Test the first_value() method.
    def test_first_value
        lib = library nil, A => ogg(foo: %w{bar}), B => ogg(foo: %w{bar})

        assert_equal("bar", lib.first_value("FOO"))

        # first_value() is designed to be called on unique tags, not unknown tags or tags with various values.
        assert_raises(::NoMethodError) { lib.first_value("BAZ") }
    end

    # Test the set_tag() method.
    def test_set_tag
        lib = library nil, A => ogg(), B => ogg()

        lib.set_tag("FOO", "bar")
        assert_summary lib, "FOO" => {0 => %w{bar}, 1 => %w{bar}}

        lib.apply(2) { |l| l.set_tag("FOO", "baz") }

        assert_summary lib, "FOO" => {0 => %w{bar}, 1 => %w{baz}}
    end

    # Test the add_tag() method.
    def test_add_tag
        lib = library nil, A => ogg(foo: %w{bar}), B => ogg()

        lib.add_tag("FOO", "baz")

        assert_summary lib, "FOO" => {0 => %w{bar baz}, 1 => %w{baz}}

        lib.apply(2) { |l| l.add_tag("FOO", "qux") }

        assert_summary lib, "FOO" => {0 => %w{bar baz}, 1 => %w{baz qux}}
    end

    # Test the rm_tag() method.
    def test_rm_tag
        lib = library nil, A => ogg(foo: %w{bar baz qux}), B => ogg(foo: %w{bar baz qux})

        lib.rm_tag("FOO", "bar")

        assert_summary lib, "FOO" => {0 => %w{baz qux}, 1 => %w{baz qux}}

        lib.apply(2) { |l| l.rm_tag("FOO") }

        assert_summary lib, "FOO" => {0 => %w{baz qux}}
    end

    # Test the ls() method.
    def test_ls
        lib = library nil, C => ogg(), A => ogg(), B => ogg()
        lib.select %w{2}

        assert_equal([{file: "/foo/bar/a.ogg", position: 1, selected: false},
                      {file: "/foo/bar/b.ogg", position: 2, selected: true},
                      {file: "/foo/bar/c.ogg", position: 3, selected: false}],
                      lib.ls)
    end

    # Test the auto_tracknumber() method.
    def test_auto_tracknumber
        lib = library nil, C => ogg(), A => ogg(), B => ogg()

        lib.select(%w{2 3}).auto_tracknumber()

        assert_summary lib, "TRACKNUMBER" => {1 => %w{1}, 2 => %w{2}}
    end


    # Helper method to generate a library composed of a list of unrelated tracks.
    def make_singles_library
        library nil,
                A => ogg({artist: "Alice", title: "This song"   , date: 2000}),
                B => ogg({artist: "Bob"  , title: "That song"   , date: 2001}),
                C => ogg({artist: "Carol", title: "Another song", date: 2002})
    end

    # Test the check() method on a library composed on unrelated tracks.
    def test_check_singles_library
        assert_valid_library(make_singles_library)

        assert_basic_library_checks { make_singles_library }
    end


    # Helper method to generate a library representing an album.
    def make_album_library
        library Pathname.new("/foo/bar"),
                A => ogg({artist: "Alice", tracknumber: 1, title: "This song",
                          album: "This album", date: 2000}),
                B => ogg({artist: "Alice", tracknumber: 2, title: "That song",
                          album: "This album", date: 2000}),
                C => ogg({artist: "Alice", tracknumber: 3, title: "Another song",
                          album: "This album", date: 2000})
    end

    # Test the check() method on a library representing an album.
    def test_check_album_library
        assert_valid_library(make_album_library)

        assert_basic_library_checks { make_album_library }

        assert_group_library_checks { make_album_library }

        l = make_album_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMARTIST", "Foo") }
        assert_raises_metadata_error(l, "The ALBUMARTIST is not required since all tracks have the same and unique ARTIST.")
    end


    # Helper method to generate a library representing a best-of.
    def make_bestof_library
        library Pathname.new("/foo/bar"),
                A => ogg({artist: "Alice", tracknumber: 1, title: "This song",
                          date: 2000, album: "This album", albumdate: 2010}),
                B => ogg({artist: "Alice", tracknumber: 2, title: "That song",
                          date: 2001, album: "This album", albumdate: 2010}),
                C => ogg({artist: "Alice", tracknumber: 3, title: "Another song",
                          date: 2002, album: "This album", albumdate: 2010})
    end

    # Test the check() method on a library representing a best-of.
    def test_check_bestof_library
        assert_valid_library(make_bestof_library)

        assert_basic_library_checks { make_bestof_library }

        assert_group_library_checks { make_bestof_library }

        l = make_bestof_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMARTIST", "Foo") }
        assert_raises_metadata_error(l, "The ALBUMARTIST is not required since all tracks have the same and unique ARTIST.")

        l = make_bestof_library.apply(1, %w{1 3}) { |l| l.rm_tag("ALBUMDATE") }
        assert_raises_metadata_error(l, "The ALBUMDATE tag must have a single and uniq value among all songs.")

        l = make_bestof_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMDATE", "2011") }
        assert_raises_metadata_error(l, "The ALBUMDATE tag must have a single and uniq value among all songs.")
    end


    # Helper method to generate a library representing a compilation.
    def make_compilation_library
        library Pathname.new("/foo/bar"),
                A => ogg({artist: "Alice", album: "This album", tracknumber: 1,
                          title: "This song", date: 2000, albumartist: "Various artists",
                          albumdate: 2010}),
                B => ogg({artist: "Bob", album: "This album", tracknumber: 2,
                          title: "That song", date: 2001, albumartist: "Various artists",
                          albumdate: 2010}),
                C => ogg({artist: "Carol", album: "This album", tracknumber: 3,
                          title: "Another song", date: 2002, albumartist: "Various artists",
                          albumdate: 2010})
    end

    # Test the check() method on a library representing a compilation.
    def test_check_compilation_library
        assert_valid_library(make_compilation_library)

        assert_basic_library_checks { make_compilation_library }

        assert_group_library_checks { make_compilation_library }

        l = make_compilation_library.set_tag("ALBUMARTIST", "Foo").select(%w{1 3})
        assert_raises_metadata_error(l, "This album seems to be a compilation. The ALBUMARTIST tag should have the value \"Various artists\".")

        l = make_bestof_library.apply(1, %w{1 3}) { |l| l.rm_tag("ALBUMDATE") }
        assert_raises_metadata_error(l, "The ALBUMDATE tag must have a single and uniq value among all songs.")

        l = make_bestof_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMDATE", "2011") }
        assert_raises_metadata_error(l, "The ALBUMDATE tag must have a single and uniq value among all songs.")
    end


    # Test the compute_rename_mapping() method.
    def test_compute_rename_mapping
        l = make_singles_library
        newpath, mapping = l.compute_rename_mapping()

        assert_equal nil, newpath
        assert_equal Hash[A => "Alice - 2000 - This song.ogg",
                          B => "Bob - 2001 - That song.ogg",
                          C => "Carol - 2002 - Another song.ogg"], mapping

        l = make_album_library
        newpath, mapping = l.compute_rename_mapping()

        assert_equal Pathname.new("/foo/Alice - 2000 - This album"), newpath
        assert_equal Hash[A => "Alice - 2000 - This album - 1 - This song.ogg",
                          B => "Alice - 2000 - This album - 2 - That song.ogg",
                          C => "Alice - 2000 - This album - 3 - Another song.ogg"], mapping

        l = make_bestof_library
        newpath, mapping = l.compute_rename_mapping()

        assert_equal Pathname.new("/foo/Alice - 2010 - This album"), newpath
        assert_equal Hash[A => "Alice - 2010 - This album - 1 - This song - 2000.ogg",
                          B => "Alice - 2010 - This album - 2 - That song - 2001.ogg",
                          C => "Alice - 2010 - This album - 3 - Another song - 2002.ogg"], mapping

        l = make_compilation_library
        newpath, mapping = l.compute_rename_mapping()

        assert_equal Pathname.new("/foo/This album - 2010"), newpath
        assert_equal Hash[A => "This album - 2010 - 1 - Alice - This song - 2000.ogg",
                          B => "This album - 2010 - 2 - Bob - That song - 2001.ogg",
                          C => "This album - 2010 - 3 - Carol - Another song - 2002.ogg"], mapping
    end

    # Make sure the internal filename mapping don't get broken when renaming.
    def test_auto_rename_consistency
        # Do one without the album mode
        l = make_singles_library
        a = l.files[A]
        b = l.files[B]
        c = l.files[C]

        refute_nil a
        refute_nil b
        refute_nil c

        l.select %w{1 2}

        l.auto_rename

        assert_nil l.path
        assert_same a, l.files[A.dirname + "Alice - 2000 - This song.ogg"]
        assert_same b, l.files[B.dirname + "Bob - 2001 - That song.ogg"]
        assert_same c, l.files[C]

        l.select_all
        a.set_values("DATE", "2003")

        l.auto_rename

        assert_nil l.path
        assert_same a, l.files[A.dirname + "Alice - 2003 - This song.ogg"]
        assert_same b, l.files[B.dirname + "Bob - 2001 - That song.ogg"]
        assert_same c, l.files[C.dirname + "Carol - 2002 - Another song.ogg"]


        # And one with the album mode
        l = make_compilation_library
        a = l.files[A]
        b = l.files[B]
        c = l.files[C]

        refute_nil a
        refute_nil b
        refute_nil c

        l.select %w{1 2}

        l.auto_rename

        assert_equal Pathname.new("/foo/This album - 2010"), l.path
        assert_same a, l.files[l.path + "This album - 2010 - 1 - Alice - This song - 2000.ogg"]
        assert_same b, l.files[l.path + "This album - 2010 - 2 - Bob - That song - 2001.ogg"]
        assert_same c, l.files[l.path + C.basename]

        l.select_all

        l.set_tag("ALBUM", "That album")
        l.auto_rename

        assert_equal Pathname.new("/foo/That album - 2010"), l.path
        assert_same a, l.files[l.path + "That album - 2010 - 1 - Alice - This song - 2000.ogg"]
        assert_same b, l.files[l.path + "That album - 2010 - 2 - Bob - That song - 2001.ogg"]
        assert_same c, l.files[l.path + "That album - 2010 - 3 - Carol - Another song - 2002.ogg"]
    end

    def test_auto_rename
        Dir.mktmpdir { |tmpdir|
            tmpdir = Pathname.new(tmpdir)
            dir = tmpdir + "foo"
            dir.mkdir()

            # Create some ogg files in tmpdir
            containers = make_fs_library(dir, "a.ogg", "b.ogg")
            # Set the tags of those files, and save them.
            containers["a.ogg"].set_values("ARTIST", "Alice").set_values("TITLE", "This song").set_values("DATE", "2000").write(dir + "a.ogg")
            containers["b.ogg"].set_values("ARTIST", "Bob").set_values("TITLE", "That song").set_values("DATE", "2001").write(dir + "b.ogg")

            # Build the library
            lib = OggAlbumTagger::Library.new(nil, Hash[containers.map { |p, c| [dir + p, c] }])

            lib.auto_rename

            # Make sure we find the expected filenames.
            assert_equal [dir], tmpdir.children
            assert_equal [dir + "Alice - 2000 - This song.ogg", dir + "Bob - 2001 - That song.ogg"].to_set, dir.children.to_set

            # Load the ogg files again and make sure we havn't mixed anything.
            a = OggAlbumTagger::TagContainer.new(dir + "Alice - 2000 - This song.ogg")
            b = OggAlbumTagger::TagContainer.new(dir + "Bob - 2001 - That song.ogg")

            refute_nil a
            refute_nil b

            expected_tags = %w{ARTIST TITLE DATE}.to_set
            assert_equal expected_tags, a.tags.to_set
            assert_equal expected_tags, b.tags.to_set

            assert_equal Set["Alice"]    , a["ARTIST"]
            assert_equal Set["This song"], a["TITLE"]
            assert_equal Set["2000"]     , a["DATE"]

            assert_equal Set["Bob"]      , b["ARTIST"]
            assert_equal Set["That song"], b["TITLE"]
            assert_equal Set["2001"]     , b["DATE"]
        }
    end
end

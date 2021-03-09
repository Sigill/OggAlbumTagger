require 'minitest/autorun'
require 'set'
require 'fileutils'
require 'pathname'

require 'ogg_album_tagger/tag_container'
require 'ogg_album_tagger/ogg_file'
require 'ogg_album_tagger/library'

require 'library_helper'

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
            lib = yield.apply(1, %w{1 3}) { |l| l.rm_tag(t) }
            assert_raises_metadata_error(lib, "The #{t} tag must be used once per track.")
        }

        %w{ARTIST TITLE DATE ALBUM ALBUMDATE ARTISTALBUM TRACKNUMBER DISCNUMBER}.each { |t|
            lib = yield.apply(1, %w{1 3}) { |l| l.set_tag(t, "one", "two") }
            assert_raises_metadata_error(lib, "The #{t} tag must not appear more than once per track.")
        }

        %w{DISCNUMBER TRACKNUMBER}.each { |t|
            lib = yield.apply(1, %w{1 3}) { |l| l.set_tag(t, "foo") }
            assert_raises_metadata_error(lib, "If used, the #{t} tag must have a numeric value.")
        }

        %w{DATE ALBUMDATE}.each { |t|
            lib = yield.apply(1, %w{1 3}) { |l| l.set_tag(t, "20000") }
            assert_raises_metadata_error(lib, "If used, the #{t} tag must be a valid year.")
        }
    end

    # Verify that the tag constraints specific to "group" library (album, compilation, best-of) are respected.
    #
    # This assertion takes a block that returns a valid library and verify that the following
    # changes will get check() to raise a MetadataError exception:
    # - the _TRACKNUMBER_ tag is missing.
    # - the _ALBUM_ tag does not have a unique value across the tracks.
    def assert_group_library_checks
        lib = yield.apply(1, %w{1 3}) { |l| l.rm_tag("TRACKNUMBER") }
        assert_raises_metadata_error(lib, "The TRACKNUMBER tag must be used once per track.")

        lib = yield.apply(1, %w{1 3}) { |l| l.set_tag("ALBUM", "another") }
        assert_raises_metadata_error(lib, "The ALBUM tag must have a single and unique value among all songs.")
    end
end

# Thests for the Library class.
class LibraryTest < Minitest::Test
    DIR = Pathname.new("/foo/bar").freeze
    A = (DIR + "a.ogg").freeze
    B = (DIR + "b.ogg").freeze
    C = (DIR + "c.ogg").freeze
    D = (DIR + "d.ogg").freeze

    # Helper method that build a TagContainer object from the specified tags.
    def ogg(path, tags = {})
        TestingFile.new(path, tags)
    end

    # Helper method to build a mocked library.
    def library(dir, *tracks)
        TestingLibrary.new(dir, tracks)
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

            [relpath, OggAlbumTagger::OggFile.new(path)]
        }.to_h
    end

    # Test the select() and build_selection() methods.
    def test_selection
        a = ogg(A)
        b = ogg(B)
        c = ogg(C)
        d = ogg(D)

        lib = library nil, a, b, c, d
        assert_equal Set[a, b, c, d], lib.selected_files

        lib.select(%w{1})
        assert_equal Set[a], lib.selected_files

        lib.select(%w{+2})
        assert_equal Set[a, b], lib.selected_files

        lib.select(%w{-2})
        assert_equal Set[a], lib.selected_files

        lib.select(%w{3-4})
        assert_equal Set[c, d], lib.selected_files

        lib.select(%w{1 2})
        assert_equal Set[a, b], lib.selected_files

        lib.select(%w{2 3-4})
        assert_equal Set[b, c, d], lib.selected_files

        lib.select(%w{all})
        assert_equal Set[a, b, c, d], lib.selected_files

        lib.select(%w{-2-3})
        assert_equal Set[a, d], lib.selected_files

        lib.select(%w{+2-3})
        assert_equal Set[a, b, c, d], lib.selected_files

        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{+1 all}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{foo}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{0}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{5}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{+bar}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{+0}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{-5}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{4-2}) }

        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{+1 2}) }
        assert_raises(OggAlbumTagger::ArgumentError) { lib.build_selection(%w{+1 2-3}) }
    end

    # Test the tags_used() method.
    def test_tags_used
        lib = library nil
        assert_equal [] , lib.tags_used

        lib = library nil, ogg(A, foo: %w{bar}), ogg(B, baz: %w{qux})
        assert_equal %w{foo baz}, lib.tags_used

        lib = library nil, ogg(A, foo: %w{bar}), ogg(B, foo: %w{baz})
        assert_equal %w{foo}, lib.tags_used
    end

    # Test the summary() method.
    def test_summary
        lib = library nil, ogg(A, foo: %w{bar}), ogg(B, baz: %w{qux quux})
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
        lib = library nil, ogg(A, foo: %w{bar}), ogg(B, foo: %w{corge}, baz: %w{qux quux})
        assert_equal({0 => ["bar"], 1 => ["corge"]}, lib.tag_summary("FOO"))
    end

    # Test the first_value() method.
    def test_first_value
        lib = library nil, ogg(A, foo: %w{bar}), ogg(B, foo: %w{bar})

        assert_equal("bar", lib.first_value("FOO"))

        # first_value() is designed to be called on unique tags, not unknown tags or tags with various values.
        assert_raises(::NoMethodError) { lib.first_value("BAZ") }
    end

    # Test the set_tag() method.
    def test_set_tag
        lib = library nil, ogg(A), ogg(B)

        lib.set_tag("FOO", "bar")
        assert_summary lib, "FOO" => {0 => %w{bar}, 1 => %w{bar}}

        lib.apply(2) { |l| l.set_tag("FOO", "baz") }

        assert_summary lib, "FOO" => {0 => %w{bar}, 1 => %w{baz}}
    end

    # Test the add_tag() method.
    def test_add_tag
        lib = library nil, ogg(A, foo: %w{bar}), ogg(B)

        lib.add_tag("FOO", "baz")

        assert_summary lib, "FOO" => {0 => %w{bar baz}, 1 => %w{baz}}

        lib.apply(2) { |l| l.add_tag("FOO", "qux") }

        assert_summary lib, "FOO" => {0 => %w{bar baz}, 1 => %w{baz qux}}
    end

    # Test the rm_tag() method.
    def test_rm_tag
        lib = library nil, ogg(A, foo: %w{bar baz qux}), ogg(B, foo: %w{bar baz qux})

        lib.rm_tag("FOO", "bar")

        assert_summary lib, "FOO" => {0 => %w{baz qux}, 1 => %w{baz qux}}

        lib.apply(2) { |l| l.rm_tag("FOO") }

        assert_summary lib, "FOO" => {0 => %w{baz qux}}
    end

    # Test the ls() method.
    def test_ls
        lib = library nil, ogg(C), ogg(A), ogg(B)
        lib.select %w{2}

        assert_equal([{file: "/foo/bar/c.ogg", selected: false},
                      {file: "/foo/bar/a.ogg", selected: true},
                      {file: "/foo/bar/b.ogg", selected: false}],
                      lib.ls)
    end

    # Test the auto_tracknumber() method.
    def test_auto_tracknumber
        lib = library nil, ogg(C), ogg(A), ogg(B)

        lib.select(%w{2 3}).auto_tracknumber()

        assert_summary lib, "TRACKNUMBER" => {1 => %w{1}, 2 => %w{2}}
    end


    # Helper method to generate a library composed of a list of unrelated tracks.
    def make_singles_library_with_tracks
        a = ogg(A, {artist: "Alice", title: "This song"   , date: "2000"})
        b = ogg(B, {artist: "Bob"  , title: "That song"   , date: "2001"})
        c = ogg(C, {artist: "Carol", title: "Another song", date: "2002"})
        return library(nil, a, b, c), a, b, c
    end

    def make_singles_library
        lib, * = make_singles_library_with_tracks
        return lib
    end

    # Test the check() method on a library composed on unrelated tracks.
    def test_check_singles_library
        assert_valid_library(make_singles_library)

        assert_basic_library_checks { make_singles_library }
    end


    # Helper method to generate a library representing an album.
    def make_album_library_with_tracks
        a = ogg(A, {artist: "Alice", tracknumber: 1, title: "This song",
                    album: "This album", date: "2000"})
        b = ogg(B, {artist: "Alice", tracknumber: 2, title: "That song",
                    album: "This album", date: "2000"})
        c = ogg(C, {artist: "Alice", tracknumber: 3, title: "Another song",
                    album: "This album", date: "2000"})
        return library(DIR, a, b, c), a, b, c
    end

    def make_album_library
        lib, * = make_album_library_with_tracks
        return lib
    end

    # Test the check() method on a library representing an album.
    def test_check_album_library
        assert_valid_library(make_album_library)

        assert_basic_library_checks { make_album_library }

        assert_group_library_checks { make_album_library }

        lib = make_album_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMARTIST", "Foo") }
        assert_raises_metadata_error(lib, "The ALBUMARTIST is not required since all tracks have the same and unique ARTIST.")
    end


    # Helper method to generate a library representing a best-of.
    def make_bestof_library_with_tracks
        a = ogg(A, {artist: "Alice", tracknumber: 1, title: "This song",
                    date: "2000", album: "This album", albumdate: "2010"})
        b = ogg(B, {artist: "Alice", tracknumber: 2, title: "That song",
                    date: "2001", album: "This album", albumdate: "2010"})
        c = ogg(C, {artist: "Alice", tracknumber: 3, title: "Another song",
                    date: "2002", album: "This album", albumdate: "2010"})
        return library(DIR, a, b, c), a, b, c
    end

    def make_bestof_library
        lib, * = make_bestof_library_with_tracks
        return lib
    end

    # Test the check() method on a library representing a best-of.
    def test_check_bestof_library
        assert_valid_library(make_bestof_library)

        assert_basic_library_checks { make_bestof_library }

        assert_group_library_checks { make_bestof_library }

        lib = make_bestof_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMARTIST", "Foo") }
        assert_raises_metadata_error(lib, "The ALBUMARTIST is not required since all tracks have the same and unique ARTIST.")

        lib = make_bestof_library.apply(1, %w{1 3}) { |l| l.rm_tag("ALBUMDATE") }
        assert_raises_metadata_error(lib, "The ALBUMDATE tag must have a single and unique value among all songs.")

        lib = make_bestof_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMDATE", "2011") }
        assert_raises_metadata_error(lib, "The ALBUMDATE tag must have a single and unique value among all songs.")
    end


    # Helper method to generate a library representing a compilation.
    def make_compilation_library_with_tracks
        a = ogg(A, {artist: "Alice", album: "This album", tracknumber: 1,
                    title: "This song", date: "2000", albumartist: "Various artists",
                    albumdate: "2010"})
        b = ogg(B, {artist: "Bob", album: "This album", tracknumber: 2,
                    title: "That song", date: "2001", albumartist: "Various artists",
                    albumdate: "2010"})
        c = ogg(C, {artist: "Carol", album: "This album", tracknumber: 3,
                    title: "Another song", date: "2002", albumartist: "Various artists",
                    albumdate: "2010"})
        return library(DIR, a, b, c), a, b, c
    end

    def make_compilation_library
        lib, * = make_compilation_library_with_tracks
        return lib
    end

    # Test the check() method on a library representing a compilation.
    def test_check_compilation_library
        assert_valid_library(make_compilation_library)

        assert_basic_library_checks { make_compilation_library }

        assert_group_library_checks { make_compilation_library }

        lib = make_compilation_library.set_tag("ALBUMARTIST", "Foo").select(%w{1 3})
        assert_raises_metadata_error(lib, "This album seems to be a compilation. The ALBUMARTIST tag should have the value \"Various artists\".")

        lib = make_bestof_library.apply(1, %w{1 3}) { |l| l.rm_tag("ALBUMDATE") }
        assert_raises_metadata_error(lib, "The ALBUMDATE tag must have a single and unique value among all songs.")

        lib = make_bestof_library.apply(1, %w{1 3}) { |l| l.set_tag("ALBUMDATE", "2011") }
        assert_raises_metadata_error(lib, "The ALBUMDATE tag must have a single and unique value among all songs.")

        lib = make_compilation_library.set_tag("DATE", "2010")
        assert_raises_metadata_error(lib, "The ALBUMDATE tag is not required since it is unique and identical to the DATE tag.")
    end


    # Test the compute_rename_mapping() method.
    def test_compute_rename_mapping
        l, a, b, c = make_singles_library_with_tracks
        dir_fields, file_fields = l.compute_rename_fields()
        newpath, mapping = l.compute_rename_mapping(dir_fields, file_fields)

        assert_nil newpath
        assert_equal Hash[a => "Alice - 2000 - This song.ogg",
                          b => "Bob - 2001 - That song.ogg",
                          c => "Carol - 2002 - Another song.ogg"], mapping

        l, a, b, c = make_album_library_with_tracks
        dir_fields, file_fields = l.compute_rename_fields()
        newpath, mapping = l.compute_rename_mapping(dir_fields, file_fields)

        assert_equal Pathname.new("/foo/Alice - 2000 - This album"), newpath
        assert_equal Hash[a => "Alice - 2000 - This album - 1 - This song.ogg",
                          b => "Alice - 2000 - This album - 2 - That song.ogg",
                          c => "Alice - 2000 - This album - 3 - Another song.ogg"], mapping

        l, a, b, c = make_bestof_library_with_tracks
        dir_fields, file_fields = l.compute_rename_fields()
        newpath, mapping = l.compute_rename_mapping(dir_fields, file_fields)

        assert_equal Pathname.new("/foo/Alice - 2010 - This album"), newpath
        assert_equal Hash[a => "Alice - 2010 - This album - 1 - This song - 2000.ogg",
                          b => "Alice - 2010 - This album - 2 - That song - 2001.ogg",
                          c => "Alice - 2010 - This album - 3 - Another song - 2002.ogg"], mapping

        l, a, b, c = make_compilation_library_with_tracks
        dir_fields, file_fields = l.compute_rename_fields()
        newpath, mapping = l.compute_rename_mapping(dir_fields, file_fields)

        assert_equal Pathname.new("/foo/This album - 2010"), newpath
        assert_equal Hash[a => "This album - 2010 - 1 - Alice - This song - 2000.ogg",
                          b => "This album - 2010 - 2 - Bob - That song - 2001.ogg",
                          c => "This album - 2010 - 3 - Carol - Another song - 2002.ogg"], mapping

        l, a, b, c = make_compilation_library_with_tracks
        l.set_tag("DATE", "2000")
        dir_fields, file_fields = l.compute_rename_fields()
        newpath, mapping = l.compute_rename_mapping(dir_fields, file_fields)

        assert_equal Pathname.new("/foo/This album - 2010"), newpath
        assert_equal Hash[a => "This album - 2010 - 1 - Alice - This song - 2000.ogg",
                          b => "This album - 2010 - 2 - Bob - That song - 2000.ogg",
                          c => "This album - 2010 - 3 - Carol - Another song - 2000.ogg"], mapping

        l, a, b, c = make_compilation_library_with_tracks
        l.set_tag("DATE", "2010").rm_tag('ALBUMDATE')
        dir_fields, file_fields = l.compute_rename_fields()
        newpath, mapping = l.compute_rename_mapping(dir_fields, file_fields)

        assert_equal Pathname.new("/foo/This album - 2010"), newpath
        assert_equal Hash[a => "This album - 2010 - 1 - Alice - This song - 2010.ogg",
                          b => "This album - 2010 - 2 - Bob - That song - 2010.ogg",
                          c => "This album - 2010 - 3 - Carol - Another song - 2010.ogg"], mapping
    end

    # Make sure the internal filename mapping don't get broken when renaming.
    def test_auto_rename_consistency
        # Do one without the album mode
        l, a, b, c = make_singles_library_with_tracks

        l.select %w{1 2}

        l.auto_rename(nil, nil)

        assert_nil l.path
        assert_equal a.path, A.dirname + "Alice - 2000 - This song.ogg"
        assert_equal b.path, B.dirname + "Bob - 2001 - That song.ogg"
        assert_equal c.path, C

        l.select_all
        a.set_values("DATE", "2003")

        l.auto_rename(nil, nil)

        assert_nil l.path
        assert_equal a.path, A.dirname + "Alice - 2003 - This song.ogg"
        assert_equal b.path, B.dirname + "Bob - 2001 - That song.ogg"
        assert_equal c.path, C.dirname + "Carol - 2002 - Another song.ogg"


        # And one with the album mode
        l, a, b, c = make_compilation_library_with_tracks

        l.select %w{1 2}

        l.auto_rename(nil, nil)

        assert_equal Pathname.new("/foo/This album - 2010"), l.path
        assert_equal a.path, l.path + "This album - 2010 - 1 - Alice - This song - 2000.ogg"
        assert_equal b.path, l.path + "This album - 2010 - 2 - Bob - That song - 2001.ogg"
        assert_equal c.path, l.path + C.basename

        l.select_all

        l.set_tag("ALBUM", "That album")
        l.auto_rename(nil, nil)

        assert_equal Pathname.new("/foo/That album - 2010"), l.path
        assert_equal a.path, l.path + "That album - 2010 - 1 - Alice - This song - 2000.ogg"
        assert_equal b.path, l.path + "That album - 2010 - 2 - Bob - That song - 2001.ogg"
        assert_equal c.path, l.path + "That album - 2010 - 3 - Carol - Another song - 2002.ogg"
    end

    # Check the auto_rename method.
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
            lib = OggAlbumTagger::Library.new(nil, containers.map { |p, c| c })

            lib.auto_rename(nil, nil)

            # Make sure we find the expected filenames.
            assert_equal [dir], tmpdir.children
            assert_equal [dir + "Alice - 2000 - This song.ogg", dir + "Bob - 2001 - That song.ogg"].to_set, dir.children.to_set

            # Load the ogg files again and make sure we havn't mixed anything.
            a = OggAlbumTagger::OggFile.new(dir + "Alice - 2000 - This song.ogg")
            b = OggAlbumTagger::OggFile.new(dir + "Bob - 2001 - That song.ogg")

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

    # Make sure the selection can be temporarly restricted.
    def test_with_selection
        lib = library nil, ogg(A, foo: %w{bar}), ogg(B, baz: %w{qux})

        lib.with_selection(%w{2}) { assert_equal %w{baz}, lib.tags_used }

        lib.with_selection([]) { assert_equal %w{foo baz}, lib.tags_used }
    end

    # Test the move method.
    def test_move
        lib = library nil, ogg(A, a: %w{foo}), ogg(B, a: %w{bar}), ogg(C, a: %w{baz})
        assert_order lib, A, B, C

        # Move first after last
        lib.move(0, 3)
        assert_order lib, B, C, A

        # Move last before first
        lib.move(2, 0)
        assert_order lib, A, B, C

        # Do not move anything
        lib.move(1, 1)
        assert_order lib, A, B, C

        # Do not move anything
        lib.move(1, 2)
        assert_order lib, A, B, C

        # Make sure invalid indexes are catched
        e = assert_raises(::IndexError) { lib.move(-1, 0) }
        assert_equal "Invalid from index -1", e.message

        e = assert_raises(::IndexError) { lib.move(3, 0) }
        assert_equal "Invalid from index 3", e.message

        e = assert_raises(::IndexError) { lib.move(0, -1) }
        assert_equal "Invalid to index -1", e.message

        e = assert_raises(::IndexError) { lib.move(0, 4) }
        assert_equal "Invalid to index 4", e.message
    end
end

require 'minitest/autorun'
require 'fileutils'
require 'set'
require 'ogg_album_tagger/tag_container'

class TagContainerTest < Minitest::Test
    def dummy
        OggAlbumTagger::TagContainer.new(genre: %w{Acoustic Rock}, unicodetag: "öäüoΣø")
    end

    def test_valid_tag
        assert_nil OggAlbumTagger::TagContainer::valid_tag?("ABC")
        assert_raises(OggAlbumTagger::ArgumentError) { OggAlbumTagger::TagContainer::valid_tag?("") }
        assert_raises(OggAlbumTagger::ArgumentError) { OggAlbumTagger::TagContainer::valid_tag?("=") }
        assert_raises(OggAlbumTagger::ArgumentError) { OggAlbumTagger::TagContainer::valid_tag?("~") }
    end

    # Ensure the expected tags are available.
    def test_tags
        ogg = dummy()

        expected_tags = %w{GENRE UNICODETAG}.to_set
        assert_equal expected_tags, ogg.tags.to_set
    end

    # Ensure that accessing tags is case insensitive.
    def test_case_insensitive
        ogg = dummy()
        assert_same ogg['GENRE'], ogg['genre']
    end

    # Test the has_tag() method.
    def test_has_tag
        ogg = dummy()

        assert ogg.has_tag?("GENRE")
        assert !ogg.has_tag?("UNKNOWN")
    end

    # Test the get_tag() method.
    def test_get_tag
        ogg = dummy()

        assert_equal %w{Acoustic Rock}.to_set, ogg['GENRE']
        assert_equal Set["öäüoΣø"],            ogg['UNICODETAG']

        assert_empty ogg['UNKNOWN']
        assert ogg['UNKNOWN'].frozen?
    end

    def test_first
        assert_equal "Acoustic", dummy.first("GENRE")
        assert_raises(IndexError) { dummy.first("UNKNOWN") }
    end

    # Test the set_values() method.
    def test_set_values
        ogg = dummy()

        assert !ogg.has_tag?("A")

        ogg.set_values("A", "B")
        assert_equal Set["B"], ogg['A']

        ogg.set_values("A", "C", "D")
        assert_equal Set["C", "D"], ogg['A']

        # This will remove the tag
        ogg.set_values("A", *[])
        assert !ogg.has_tag?("A")
    end

    # Test the add_values() method.
    def test_add_values
        ogg = dummy()

        assert !ogg.has_tag?("A")

        ogg.add_values("A", "B")
        assert_equal Set["B"], ogg['A']

        ogg.add_values("A", "C", "D")
        assert_equal Set["B", "C", "D"], ogg['A']

        ogg.add_values("A", *[])
        assert_equal Set["B", "C", "D"], ogg['A']
    end

    # Test the rm_values() method.
    def test_rm_values
        ogg = dummy()

        ogg.add_values("GENRE", "Pop")
        assert_equal %w{Acoustic Rock Pop}.to_set, ogg['GENRE']

        ogg.rm_values("GENRE", "Rock", "Pop")

        assert_equal Set["Acoustic"], ogg['GENRE']

        ogg.rm_values("GENRE", "Acoustic")
        assert !ogg.has_tag?("GENRE")


        ogg.set_values("GENRE", "Funk")
        assert_equal Set["Funk"], ogg['GENRE']

        ogg.rm_values("GENRE")
        assert !ogg.has_tag?("GENRE")
    end
end
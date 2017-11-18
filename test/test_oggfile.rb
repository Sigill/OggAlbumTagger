require 'minitest/autorun'
require 'pathname'
require 'ogg_album_tagger/ogg_file'

class OggFileTest < Minitest::Test

    def dummy
        OggAlbumTagger::OggFile.new("test/data/tagged.ogg")
    end

    # Ensure the sorted_tags method return an alphabetically sorted list of tags,
    # except for the METADATA_BLOCK_PICTURE who comes last.
    def test_sorted_tags
        sorted = OggAlbumTagger::OggFile::sorted_tags(%w{A E C D B})
        assert_equal %w{A B C D E}, sorted

        sorted = OggAlbumTagger::OggFile::sorted_tags(%w{METADATA_BLOCK_PICTURE YEAR})
        assert_equal %w{YEAR METADATA_BLOCK_PICTURE}, sorted
    end

    # Test the creation of an OggFile from an ogg file.
    def test_read
        ogg = dummy()

        expected_tags = %w{GENRE UNICODETAG METADATA_BLOCK_PICTURE}.to_set
        assert_equal expected_tags, ogg.tags.to_set

        assert_equal %w{Acoustic Rock}.to_set, ogg['GENRE']
        assert_equal Set["öäüoΣø"],            ogg['UNICODETAG']
        assert_equal Set[LENA],                ogg['METADATA_BLOCK_PICTURE']
    end

    # Test the write method.
    def test_write
        # Use a temp directory to clean-up everything automatically.
        Dir.mktmpdir { |tmpdir|
            tmpdir = Pathname.new(tmpdir)
            file = tmpdir + "test.ogg"

            FileUtils.cp("test/data/empty.ogg", file.to_s)

            ogg = OggAlbumTagger::OggFile.new(file)
            ogg.set_values "GENRE", "Acoustic", "Rock"
            ogg.set_values "UNICODETAG", "öäüoΣø"
            ogg.set_values "METADATA_BLOCK_PICTURE", LENA
            ogg.write file.to_s

            # Make sure the data written can be properly reloaded.
            ogg2 = OggAlbumTagger::OggFile.new(file)
            assert_equal %w{GENRE UNICODETAG METADATA_BLOCK_PICTURE}.to_set, ogg2.tags.to_set
            assert_equal %w{Acoustic Rock}.to_set                          , ogg2['GENRE']
            assert_equal Set["öäüoΣø"]                                     , ogg2['UNICODETAG']
            assert_equal Set[LENA]                                         , ogg2['METADATA_BLOCK_PICTURE']
        }
    end

    LENA = "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"
end
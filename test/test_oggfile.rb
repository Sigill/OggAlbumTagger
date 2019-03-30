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

    LENA = OggAlbumTagger::Picture.new(IO.binread('test/data/lena.jpg'),
                                       TagLib::FLAC::Picture::FrontCover,
                                       'image/jpeg',
                                       64, 64,
                                       24, 0,
                                       'test/data/lena.jpg')
end

require 'shellwords'
require 'set'
require 'taglib'
require 'ogg_album_tagger/exceptions'
require 'ogg_album_tagger/tag_container'
require 'ogg_album_tagger/picture'

module OggAlbumTagger

# Store the tags of an ogg track.
#
# Each tag is associated to a Set of values.
class OggFile < OggAlbumTagger::TagContainer
    attr_accessor :path

    MBP = 'METADATA_BLOCK_PICTURE'

    # Initialize a TagContainer from an ogg file.
    def initialize(file)
        begin
            h = Hash.new

            TagLib::Ogg::Vorbis::File.open(file.to_s) do |ogg|
                ogg.tag.tap { |tags|
                    tags.field_list_map.each { |key, values|
                        h[key] = Set.new
                        values.each { |value| h[key].add(value.strip) }
                    }

                    pictures = tags.picture_list
                    unless pictures.empty?
                        h[MBP] = Set.new
                        pictures.each { |pic|
                            h[MBP].add(Picture.new(pic.data,
                                                   pic.type,
                                                   pic.mime_type,
                                                   pic.width,
                                                   pic.height,
                                                   pic.color_depth,
                                                   pic.num_colors,
                                                   pic.description))
                        }
                    end
                }
            end

            super(h)
            @path = file
        rescue Exception => ex
            STDERR.puts ex
            raise OggAlbumTagger::ArgumentError, "#{file} does not seems to be a valid ogg file."
        end
    end

    # Write the tags in the specified file.
    def write(file)
        begin
            TagLib::Ogg::Vorbis::File.open(file.to_s) do |ogg|
                tags = ogg.tag

                # Remove old tags
                tags.remove_all_fields
                tags.remove_all_pictures

                # Set new tags (Taglib will write them sorted)
                @hash.each { |tag, values|
                    next if tag == MBP

                    values.sort.each { |v| tags.add_field(tag, v, false) }
                }

                if @hash.has_key?(MBP)
                    @hash[MBP].each { |pic|
                        tags.add_picture(pic.to_taglib_flac_picture)
                    }
                end

                # Save everything
                ogg.save
            end
        rescue Exception
            raise OggAlbumTagger::ArgumentError, "#{file} cannot be written."
        end
    end

    def to_s
        OggFile.sorted_tags(@hash.keys).map do |tag|
            OggFile.pp_tag(@hash[tag])
        end.join "\n"
    end

    # Sort the tag keys alphabetically, but put METADATA_BLOCK_PICTURE at the end.
    def self.sorted_tags(tags)
        a = tags.sort
        a.delete('METADATA_BLOCK_PICTURE') and a.push('METADATA_BLOCK_PICTURE')
        block_given? ? a.each { |v| yield v } : a
    end
end

end # module OggAlbumTagger

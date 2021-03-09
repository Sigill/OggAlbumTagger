require 'shellwords'
require 'set'
require 'ogg_album_tagger/exceptions'
require 'ogg_album_tagger/tag_container'
require 'ogg_album_tagger/picture'
require 'base64'
require 'image_size'
require 'open3'
require 'json'
require 'tempfile'

module OggAlbumTagger

OGG_JSON_SCRIPT = File.join(File.dirname(__FILE__), "../../bin/ogg-json.py")

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

            stdout_str, stderr_str, status = Open3.capture3('python3', OGG_JSON_SCRIPT, '-l', file.to_s)
            if status != 0 then
                raise StandardError.new("Unable to parse #{file}: #{stderr_str.strip()}")
            end

            tags = JSON.parse(stdout_str)

            tags.each { |tag, values|
                h[tag] = Set.new
                if tag.upcase == MBP then
                    values.each { |v|
                        pic = Picture.new(Base64.strict_decode64(v['data']), v['type'], v['desc'], v['mime'], v['width'], v['height'], v['depth'])
                        h[tag].add(pic)
                    }
                else
                    values.each { |v| h[tag].add(v.strip) }
                end
            }

            super(h)
            @path = file
        rescue => ex
            STDERR.puts ex
            raise OggAlbumTagger::ArgumentError, "#{file} does not seems to be a valid ogg file."
        end
    end

    # Write the tags in the specified file.
    def write(file)
        begin
            data = {}
            @hash.each { |tag, values|
                if tag == MBP
                    data[tag] = values.to_a.map { |v| v.to_h }
                else
                    data[tag] = values.to_a
                end
            }

            # File.open(file.to_s + '.json', 'w:UTF-8') { |io|
            #     io.write(JSON.pretty_generate(data))
            # }

            Tempfile.create(['ogg', '.json'], Dir.tmpdir, encoding: 'UTF-8') { |json|
                json << JSON.pretty_generate(data)
                json.close

                stdout_str, stderr_str, status = Open3.capture3('python3', OGG_JSON_SCRIPT, '-w', json.path.to_s, file.to_s)
                if status != 0 then
                    raise StandardError.new("Unable to write tags to #{file}: #{stderr_str.strip()}")
                end
            }
        rescue => ex
            STDERR.puts ex
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

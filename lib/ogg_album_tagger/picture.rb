require 'base64'
require 'exiftool'
require 'filesize'
require 'taglib'
require 'ogg_album_tagger/exceptions'

module OggAlbumTagger

class Picture
    attr_reader :data, :type, :mimetype, :width, :height, :depth, :colors, :desc

    def initialize(data, type, mimetype, width, height, depth, colors, desc = '')
        @data     = data.unpack('C*') # Might be UTF8
        @type     = type
        @mimetype = mimetype
        @width    = width
        @height   = height
        @depth    = depth
        @colors   = colors
        @desc     = desc || ''

        @hash     = [@data, @type, @mimetype, @width, @height, @depth, @colors, @desc].hash
        freeze
    end

    def self.from_file(image, desc = '')
        begin
            image   = File.expand_path(image)
            meta    = Exiftool.new(image).results[0].to_hash
            content = IO.binread(image)
        rescue Exiftool::ExiftoolNotInstalled
            raise OggAlbumTagger::SystemError, "exiftool (the executable, not the gem) is not in your path, please install it."
        rescue
            raise OggAlbumTagger::ArgumentError, "\"#{image}\" cannot be read."
        end

        OggAlbumTagger::Picture.new(content,
                                    TagLib::FLAC::Picture::FrontCover,
                                    meta[:mime_type],
                                    meta[:image_width], meta[:image_height],
                                    meta[:color_components] * meta[:bits_per_sample],
                                    0,
                                    desc)
    end

    def to_s
        hsh = "0x#{hash.abs.to_s(16)[0..7]}"
        sz  = Filesize.from("#{@data.size} B").pretty
        s   = "#{hsh} #{@width}x#{@height} #{sz} #{@mimetype}"
        s  += " \"#{@desc}\"" unless @desc.empty?
        s
    end

    alias :inspect :to_s

    def ==(o)
        [@data, @type, @mimetype, @width, @height, @depth, @colors, @desc] == [o.data, o.type, o.mimetype, o.width, o.height, o.depth, o.colors, o.desc]
    end

    alias eql? ==

    def hash
        @hash
    end

    def to_mbp
        p = TagLib::FLAC::Picture.new
        p.data        = @data.pack('C*')
        p.type        = @type
        p.mime_type   = @mimetype
        p.width       = @width
        p.height      = @height
        p.color_depth = @depth
        p.num_colors  = @colors
        p.description = @desc
        return Base64.strict_encode64(p.render())
    end
end

end

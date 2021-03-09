require 'base64'
require 'exiftool'
require 'filesize'
require 'ogg_album_tagger/exceptions'
require 'json'

module OggAlbumTagger

class Picture
    attr_reader :data, :type, :desc, :mime, :width, :height, :depth

    def initialize(data, type, desc, mime, width, height, depth)
        @data     = data
        @type     = type
        @mime     = mime
        @width    = width
        @height   = height
        @depth    = depth
        @depts    = depth
        @desc     = desc

        @hash     = [@data, @type, @desc, @mime, @width, @height, @depth].hash
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
                                    3, # Front
                                    desc,
                                    meta[:mime_type],
                                    meta[:image_width], meta[:image_height],
                                    meta[:color_components] * meta[:bits_per_sample])
    end

    def to_s
        hsh = "0x#{hash.abs.to_s(16)[0..7]}"
        sz  = Filesize.from("#{@data.size} B").pretty
        s   = "#{hsh} #{@width}x#{@height} #{sz} #{@mime}"
        s  += " \"#{@desc}\"" unless @desc.empty?
        s
    end

    alias :inspect :to_s

    def ==(o)
        [@data, @type, @desc, @mime, @width, @height, @depth] == [o.data, o.type, o.desc, o.mime, o.width, o.height, o.depth]
    end

    alias eql? ==

    def hash
        @hash
    end

    def to_h
        return {
            'data'        => Base64.strict_encode64(@data),
            'type'        => @type,
            'mime'        => @mime,
            'desc'        => @desc,
            'width'       => @width,
            'height'      => @height,
            'depth'       => @depth
        }
    end
end

end

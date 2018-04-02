require 'shellwords'
require 'set'
require 'ogg_album_tagger/exceptions'

module OggAlbumTagger

# A TagContainer is basically a hashmap associating a name to a set of string values.
#
# The keys of the hashmap (aka the tags) are case insensitive (they are stored upcase).
# A tag cannot be an empty string or containe the "=" or "~" characters.
# Tags with no values are automatically removed.
class TagContainer
    # Allow to build a TagContainer using the following syntax:
    #
    # <tt>t = TagContainer.new artist: "Alice", genre: %w{Pop Rock}, tracknumber: 1, ...</tt>
    # The values associated to a tag are automatically casted to a String.
    # Single values are treated as an array of one value.
    def initialize tags = {}
        @hash = Hash.new

        tags.each { |tag, values|
            next if values.nil?

            values = [values] unless values.is_a?(Array) or values.is_a?(Set)

            next if values.empty?

            prepare_tag(tag.to_s.upcase)
            values.each { |value| @hash[tag.to_s.upcase].add(value) }
        }
    end

    # Returns a Set containing the values associated to the specified tag.
    #
    # If the tag does not exists, returns an empty Set.
    # Do not use the returned Set to add new tags, use the methods provided by the class.
    def [](tag)
        has_tag?(tag) ? @hash[tag.upcase] : Set.new.freeze
    end

    def first(tag)
        if has_tag?(tag)
            return @hash[tag.upcase].first
        else
            raise IndexError, "Tag \"#{tag}\" does not exists."
        end
    end

    # Check if the specified tag is present in the container.
    def has_tag? tag
        @hash.has_key?(tag.upcase)
    end

    # Check if the tag is valid, otherwise raise an ArgumentError.
    # Valid tags are composed of any character from " " to "}", excluding "=" and "~".
    def self.valid_tag? tag
        raise ArgumentError, "Invalid tag." unless TagLib::Ogg::XiphComment::check_key(tag)
    end

    # If the specified tag is absent from the container, associate an empty Set to it.
    def prepare_tag tag
        TagContainer::valid_tag? tag
        @hash[tag.upcase] = Set.new unless self.has_tag?(tag)
    end

    # Add some values to the specified tag.
    # Any previous values will be removed.
    def set_values(tag, *values)
        if values.empty?
            rm_values(tag)
        else
            prepare_tag tag
            @hash[tag.upcase].replace(values)
        end

        self
    end

    # Add some values to the specified tag.
    def add_values(tag, *values)
        return if values.empty?

        prepare_tag tag
        @hash[tag.upcase].merge(values)

        self
    end

    # Remove some tags. If no value is specified, the specified tag is removed.
    def rm_values(tag, *values)
        TagContainer::valid_tag? tag

        if values.empty?
            @hash.delete(tag.upcase)
        else
            @hash[tag.upcase].subtract(values)
            @hash.delete(tag.upcase) if @hash[tag.upcase].empty?
        end

        self
    end

    # Returns the list of present tags.
    def tags
        @hash.keys
    end

    # Iterate through the available tags.
    def each
        @hash.each { |tag, set| yield(tag, set) }
    end

    # Pretty print an array of values.
    def self.pp_tag values
        values_str = values.map { |v| v.to_s.length > 64 ? (v.to_s.slice(0, 64) + '...') : v.to_s }

        case values.length
        when 0 then '- (empty)'
        when 1 then values_str[0]
        else sprintf("(%d) [%s]", values.length, values_str.join(', '))
        end
    end

    private :prepare_tag
end

end # module OggAlbumTagger

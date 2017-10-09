require 'shellwords'
require 'set'
require 'ogg_album_tagger/exceptions'
require 'taglib'

module OggAlbumTagger

# Store the tags of an ogg track.
#
# Each tag is associated to a Set of values.
class TagContainer
	# Initialize a TagContainer from an ogg file.
	def initialize(file)
		@hash = Hash.new

		begin
			TagLib::Ogg::Vorbis::File.open(file.to_s) do |ogg|
				ogg.tag.field_list_map.each do |tag, values|
					prepare_tag(tag.upcase)

					values.each do |value|
						@hash[tag.upcase].add(value.strip)
					end
				end
			end
		rescue Exception => ex
			#STDERR.puts ex
			raise OggAlbumTagger::ArgumentError, "#{file} does not seems to be a valid ogg file."
		end
	end

	# Write the tags in the specified file.
	def write(file)
		begin
			TagLib::Ogg::Vorbis::File.open(file.to_s) do |ogg|
				tags = ogg.tag

				# Remove old tags
				tags.field_list_map.keys.each { |t| tags.remove_field(t) }

				# Set new tags (Taglib will write them sorted)
				@hash.each do |tag, values|
					values.sort.each do |v|
						tags.add_field(tag, v, false)
					end
				end

				# Save everything
				ogg.save
			end
		rescue Exception => ex
			#STDERR.puts ex
			raise OggAlbumTagger::ArgumentError, "#{file} cannot be written."
		end
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
		raise ArgumentError, "Invalid tag." unless tag =~ /^[\x20-\x3C\x3E-\x7D]+$/
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
	end

	# Add some values to the specified tag.
	def add_values(tag, *values)
		return if values.empty?

		prepare_tag tag
		@hash[tag.upcase].merge(values)
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
	end

	# Returns the list of present tags.
	def tags
		@hash.keys
	end

	# Iterate through the available tags.
	def each
		@hash.each { |tag, set| yield(tag, set) }
	end

	def to_s
		TagContainer.sorted_tags(@hash.keys).map do |tag|
			TagContainer.pp_tag(@hash[tag])
		end.join "\n"
	end

	# Sort the tag keys alphabetically, but put METADATA_BLOCK_PICTURE at the end.
	def self.sorted_tags(tags)
		a = tags.sort
		a.delete('METADATA_BLOCK_PICTURE') and a.push('METADATA_BLOCK_PICTURE')
		block_given? ? a.each { |v| yield v } : a
	end

	# Pretty print an array of values.
	def self.pp_tag values
		values_str = values.map { |v| v.to_s.length > 64 ? (v.to_s.slice(0, 64) + '...') : v }

		case values.length
		when 0 then '- (empty)'
		when 1 then values_str[0]
		else sprintf("(%d) [%s]", values.length, values_str.join(', '))
		end
	end

	private :prepare_tag
end

end

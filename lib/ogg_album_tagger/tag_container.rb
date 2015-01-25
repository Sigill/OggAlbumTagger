require 'shellwords'
require 'set'

module OggAlbumTagger

# Store the tags of an ogg track.
#
# Each tag is associated to a Set of values.
class TagContainer
	# Initialize a TagContainer from an ogg file.
	def initialize(file)
		@hash = Hash.new 

		begin
			dump = `#{Shellwords.shelljoin ['vorbiscomment', '-l', file]}`
		rescue
			raise RuntimeError, 'Failed to invoke vorbiscomment. Make sure it is in your path.'
		end

		raise ArgumentError, "#{file} does not seems to be a valid ogg file." if $?.exitstatus != 0

		dump.each_line do |l|
			tag, value = l.split('=', 2)
			prepare_tag(tag)
			@hash[tag.upcase].add(value.strip)
		end
	end

	# Returns a Set containing the values associated to the specified tag.
	#
	# If the tag does not exists, returns an empty Set.
	# Do not use the returned Set to add new tags, use the methods provided by the class.
	def [](tag)
		has_tag?(tag) ? @hash[tag.upcase] : Set.new.freeze
	end

	# Check if the specified tag is present in the container.
	def has_tag? tag
		@hash.has_key?(tag.upcase)
	end

	# If the specified tag is absent from the container, associate an it to an empty Set.
	def prepare_tag tag
		@hash[tag.upcase] = Set.new unless self.has_tag?(tag)
	end

	# Add some values to the specified tag.
	# Any previous values will be removed.
	def set_values(tag, *values)
		prepare_tag tag
		@hash[tag.upcase].replace(values)
	end

	# Add some values to the specified tag.
	def add_values(tag, *values)
		prepare_tag tag
		@hash[tag.upcase].merge(values)
	end

	# Remove some tags. If no value is specified, the specified tag is removed.
	def rm_values(tag, *values)
		if values.empty? then @hash.delete(tag.upcase)
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

	# Convert the container to a string that vorbiscomment can read.
	def to_vorbiscomment
		data = []

		TagContainer.sorted_tags(@hash.keys) do |tag|
			@hash[tag].to_a.sort.each { |v| data << "#{tag}=#{v}" }
		end

		data.join "\n"
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

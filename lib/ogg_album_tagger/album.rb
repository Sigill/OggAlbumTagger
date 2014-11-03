require 'ogg_album_tagger/version'
require 'ogg_album_tagger/tag_container'

require 'set'
require 'shellwords'
require 'pathname'

module OggAlbumTagger

# An Album is just a hash associating each ogg file found in a directory
# to a TagContainer. A subset of file can be selected in order to be tagged.
class Album
	attr_reader :selected_files

	# Parse each ogg file found in the specified directory (and subdirectories, recursively).
	#
	# A RuntimeError may be raised if vorbiscomment cannot be invoked or if one of the files
	# is not a valid ogg file.
	def initialize path
		@path = Pathname.new File.expand_path(path)
		@files = {}

		Dir.glob("#{@path.to_s.gsub(/([\[\]\{\}\*\?\\])/, '\\\\\1')}/**/*.ogg") do |song|
			rel_path = Pathname.new(song).relative_path_from(@path)
			@files[rel_path] = TagContainer.new(song)
		end

		@selected_files = Set.new @files.keys
	end

	# Returns the list of the tags used in the selected files.
	def tags_used
		s = Set.new
		@selected_files.each do |file|
			s.merge @files[file].tags
		end
		s.to_a.map { |v| v.downcase }
	end

	# Returns an hash of hashes describing the selected files for the specified tags.
	#
	# If no tag is specified, all tags are considered.
	#
	# The first hash is indexed by the tags used. The second level of hashes is indexed
	# by the positions of the files in the album and points to a alphabetically sorted list
	# of values associated to the tag.
	#
	# {
	# 	'TITLE' => {
	# 		0 => ['Title of track 0'],
	# 		3 => ['Title of track 3']
	# 	},
	# 	...
	# }
	def summary(selected_tag = nil)
		data = Hash.new { |h, k| h[k] = Hash.new }

		positions = Hash[@files.keys.sort.each_with_index.to_a]

		@selected_files.each do |file|
			@files[file].each do |k, v|
				next unless selected_tag.nil? or k.eql?(selected_tag)
				data[k][positions[file]] = v.to_a.sort
			end
		end

		data
	end

	# Write the tags to the files.
	def write
		@files.each do |file, tags|
			command = "#{Shellwords.shelljoin ['vorbiscomment', '-w', File.join(@path, file)]}"
			o, s = Open3.capture2(command, :stdin_data => tags.to_vorbiscomment())
		end
	end

	# Tags the selected files with the specified values.
	#
	# Any previous value will be removed.
	def set_tag(tag, *values)
		tag.upcase!
		@selected_files.each { |file| @files[file].set_values(tag, *values) }
	end

	# Tags the selected files with the specified values.
	def add_tag(tag, *values)
		tag.upcase!
		@selected_files.each { |file| @files[file].add_values(tag, *values) }
	end

	# Remove the specified values from the selected files.
	#
	# If no value is specified, the tag will be removed.
	def rm_tag(tag, *values)
		tag.upcase!
		@selected_files.each { |file| @files[file].rm_values(tag, *values) }
	end

	# Return a list of the files in this album.
	def ls
		@files.keys.sort.each_with_index.map do |file, i|
			{ file: file, position: i+1, selected: @selected_files.include?(file) }
		end
	end

	# Modify the list of selected files.
	#
	# The available selector are:
	# * "all": all files.
	# * "3": the third file.
	# * "5-7" the files 5, 6 and 7.
	#
	# The two last selector can be prefixed by "+" or "-" in order to add or remove items
	# from the current selection. They are called cumulative selectors.
	#
	# You can specify several selectors, but non-cumulative selectors cannot be specified after a cumulative one.
	def select(args)
		all_files = @files.keys.sort
		mode = :absolute

		first_rel = !!(args.first =~ /^[+-]/)

		sel = first_rel ? Set.new(@selected_files) : Set.new

		args.each do |selector|
			case selector
			when 'all'
				raise ArgumentError, "Cannot use the \"#{selector}\" selector after a cumulative selector (+/-...)" if mode == :cumulative
				sel.replace all_files
			when /^([+-]?)([1-9]\d*)$/
				i = $2.to_i - 1
				raise ArgumentError, "Item #{$2} is out of range" if i >= all_files.length

				items = [all_files.slice(i)]
				case $1
				when '-'
					sel.subtract items
					mode = :cumulative
				when '+'
					sel.merge items
					mode = :cumulative
				else
					raise ArgumentError, "Cannot use the \"#{selector}\" selector after a cumulative selector (+/-...)" if mode == :cumulative
					sel.merge items
				end
			when /^([+-]?)(?:([1-9]\d*)-([1-9]\d*))$/
				i = $2.to_i - 1
				j = $3.to_i - 1
				raise ArgumentError, "Range #{$2}-#{$3} is invalid" if i >= all_files.length or j >= all_files.length or i > j

				items = all_files.slice(i..j)
				case $1
				when '-'
					sel.subtract items
					mode = :cumulative
				when '+'
					sel.merge items
					mode = :cumulative
				else
					raise ArgumentError, "Cannot use the \"#{selector}\" selector after a cumulative selector (+/-...)" if mode == :cumulative
					sel.merge items
				end
			end
		end

		@selected_files.replace sel
	end

	# Automatically set the TRACKNUMBER tag of the selected files based on their position in the selection.
	def auto_tracknumber
		@selected_files.sort.each_with_index do |file, i|
			@files[file].set_values('TRACKNUMBER', (i+1).to_s)
		end
	end

	# Test if a tag satisfy a predicate on each selected files.
	def validate_tag(tag)
		values = @selected_files.map { |file| @files[file][tag] }
		values.reduce(true) { |r, v| r && yield(v) }
	end

	# Test if a tag is used k times on each selected files.
	def tag_used_k_times?(tag, k)
		self.validate_tag(tag) { |v| v.size == k }
	end

	# Test if a tag is used once on each selected files.
	def tag_used_once?(tag)
		self.tag_used_k_times?(tag, 1)
	end

	# Test if a tag is absent from each selected files.
	def tag_unused?(tag)
		self.tag_used_k_times?(tag, 0)
	end

	# Test if multiple tags satisfy a predicate.
	def validate_tags(tags)
		tags.reduce(true) { |result, tag| result && yield(tag) }
	end

	# Test if a tag has a single value and is uniq across all selected files.
	def uniq_tag?(tag)
		values = @selected_files.map { |file| @files[file][tag] }
		values.reduce(true) { |r, v| r && (v.size == 1) } && (values.map { |v| v.first }.uniq.length == 1)
	end

	# Test if a tag holds a numerical value > 0.
	def numeric_tag?(tag)
		validate_tag(tag) { |v| v.first =~ /^[1-9][0-9]*$/ }
	end

	# Verify that the album is properly tagged.
	#
	# * ALBUM must be uniq.
	# * ALBUMARTIST must be uniq unless this album is a compilation
	# * ARTIST, TRACKNUMBER, TITLE and DATE must be used once time per file.
	# * DISCNUMBER must be used at most one time per file.
	# * TRACKNUMBER and DISCNUMBER must have numerical values.
	#
	# TODO Check ALBUMARTIST for "Various artists" in compilations.
	# TODO Check DATE for being a year.
	def check(type)
		uniq_tags = %w{ALBUM}
		uniq_tags << 'ALBUMARTIST' if type == 'album'

		common_tags = %w{ARTIST TRACKNUMBER TITLE DATE}

		required_tags = uniq_tags + common_tags

		unless validate_tags(uniq_tags) { |tag| uniq_tag?(tag) }
			raise RuntimeError, "Each of the following tags must have a single and uniq value among all songs: #{uniq_tags.join ', '}."
		end

		unless validate_tags(common_tags) { |tag| tag_used_once?(tag) }
			raise RuntimeError, "Each of the following tags must be used once per track: #{common_tags.join ', '}."
		end

		unless tag_unused?('DISCNUMBER') or tag_used_once?('DISCNUMBER')
			raise RuntimeError, 'The DISCNUMBER tag must be either unused or used once per track.'
		end

		numeric_tags = %w{TRACKNUMBER}
		numeric_tags << 'DISCNUMBER' if self.tag_used_once?('DISCNUMBER')
		unless validate_tags(numeric_tags) { |tag| numeric_tag?(tag) }
			raise RuntimeError, "The following tags must have numeric values: #{numeric_tags.join ', '}."
		end
	end

	# Auto rename the directory and the ogg files of the album.
	#
	# For an album, the format is:
	# Ogg file:  ARTIST - DATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE
	# Directory: ALBUMARTIST - DATE - ALBUM
	#
	# For a compilation, the format is:
	# Ogg file:  ALBUM - [DISCNUMBER.]TRACKNUMBER - ARTIST - DATE - TITLE
	# Directory: ALBUM - DATE
	#
	# Disc and track numbers are padded with zeros.
	def auto_rename(type)
		check(type)

		tn_maxlength = $album.summary('TRACKNUMBER')['TRACKNUMBER'].values.map { |v| v.first }.max_by { |v| v.length }.length
		tn_format = '%0' + tn_maxlength.to_s + 'd'

		has_discnumber = self.tag_used_once?('DISCNUMBER')
		if has_discnumber
			dn_maxlength = $album.summary('DISCNUMBER')['DISCNUMBER'].values.map { |v| v.first }.max_by { |v| v.length }.length
			dn_format = '%0' + dn_maxlength.to_s + 'd'
		end

		format_number = lambda do |tags|
			s = ''
			if has_discnumber
				s += sprintf(dn_format, tags['DISCNUMBER'].first.to_i) + '.'
			end
			s += sprintf(tn_format, tags['TRACKNUMBER'].first.to_i)
		end

		case type
		when 'album'
			mapping = {}
			@selected_files.each do |file|
				tags = @files[file]
				mapping[file] = sprintf('%s - %s - %s - %s - %s.ogg',
					tags['ARTIST'].first, tags['DATE'].first, tags['ALBUM'].first,
					format_number.call(tags),
					tags['TITLE'].first)
			end

			dirname = sprintf('%s - %s - %s',
				$album.summary('ALBUMARTIST')['ALBUMARTIST'].first[1].first,
				$album.summary('DATE')['DATE'].first[1].first,
				$album.summary('ALBUM')['ALBUM'].first[1].first)
		when 'compilation'
			mapping = {}
			@selected_files.each do |file|
				tags = @files[file]
				mapping[file] = sprintf('%s - %s - %s - %s - %s.ogg',
					tags['ALBUM'].first, format_number.call(tags),
					tags['ARTIST'].first, tags['DATE'].first, tags['TITLE'].first)
			end

			dirname = sprintf('%s - %s',
				$album.summary('ALBUM')['ALBUM'].first[1].first,
				$album.summary('DATE')['DATE'].first[1].first)
		end

		if mapping.values.uniq.size != @selected_files.size
			raise RuntimeError, 'Generated filenames are not uniq.'
		end

		# TODO Should UTF-8 chars be removed in order to have Windows-safe ?

		begin
			# Remove unauthorized chars
			path = @path.dirname + dirname.gsub(/[\\\/:*?"<>|]/, '')
			if @path != path
				FileUtils.mv(@path, path)
				@path = path
			end
		rescue Exception => ex
			raise RuntimeError, "Cannot rename #{@path} to #{path}."
		end

		Set.new(@selected_files).each do |file|
			begin
				oldpath = File.join(@path, file)
				newpath = File.join(@path, mapping[file].gsub(/[\\\/:*?"<>|]/, ''))

				if oldpath != newpath
					FileUtils.mv(oldpath, newpath)
					@files[mapping[file]] = @files.delete(file)
				end

				@selected_files.delete(file).add(mapping[file])
			rescue Exception => ex
				raise RuntimeError, "Cannot rename #{File.join(@path, file)} to #{File.join(@path, mapping[file])}."
			end
		end
	end
end

end

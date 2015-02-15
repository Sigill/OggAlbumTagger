require 'ogg_album_tagger/version'
require 'ogg_album_tagger/tag_container'
require 'ogg_album_tagger/exceptions'

require 'set'
require 'shellwords'
require 'pathname'
require 'open3'
require 'fileutils'

module OggAlbumTagger

# A Library is just a hash associating each ogg file to a TagContainer.
# A subset of file can be selected in order to be tagged.
class Library
	attr_reader :selected_files

	# Build the library by parsing specified ogg file.
	# In order to consider the library as a single album, you have to separately provide
	# the absolute path to the album and relative paths to the ogg files.
	# Otherwise, use absolute paths.
	#
	# Paths must be provided as Pathnames.
	#
	# A OggAlbumTagger::SystemError will be raised if vorbiscomment cannot be invoked.
	# A OggAlbumTagger::ArgumentError will be raised if one of the files is not a valid ogg file.
	def initialize files, dir = nil
		@path = dir
		@files = {}

		files.each do |f|
			@files[f] = TagContainer.new(fullpath(f))
		end

		@selected_files = Set.new @files.keys
	end

	# Return the full path to the file.
	def fullpath(file)
		@path.nil? ? file : @path + file
	end

	# Returns the list of the tags used in the selected files.
	def tags_used
		s = Set.new
		@selected_files.each do |file|
			s.merge @files[file].tags
		end
		s.to_a.map { |v| v.downcase }
	end

	# Returns an hash of hashes describing the selected files for the specified tag.
	#
	# If no tag is specified, all tags are considered.
	#
	# The first hash is indexed by the tags used. The second level of hashes is indexed
	# by the positions of the files in the library and points to a alphabetically sorted list
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

	# Returns a hash where keys are the positions of the files in the library
	# and values are sorted lists of values associated to the tag.
	def tag_summary(tag)
		summary(tag)[tag]
	end

	# Pick from the selected files one single value associated to the specified tag.
	def first_value(tag)
		tag_summary(tag).first[1].first
	end

	# Write the tags to the files.
	def write
		@selected_files.each do |file|
			@files[file].write(fullpath(file))
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

	# Return a list of the files in the library.
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
				raise OggAlbumTagger::ArgumentError, "Cannot use the \"#{selector}\" selector after a cumulative selector (+/-...)" if mode == :cumulative
				sel.replace all_files
			when /^([+-]?)([1-9]\d*)$/
				i = $2.to_i - 1
				raise OggAlbumTagger::ArgumentError, "Item #{$2} is out of range" if i >= all_files.length

				items = [all_files.slice(i)]
				case $1
				when '-'
					sel.subtract items
					mode = :cumulative
				when '+'
					sel.merge items
					mode = :cumulative
				else
					raise OggAlbumTagger::ArgumentError, "Cannot use the \"#{selector}\" selector after a cumulative selector (+/-...)" if mode == :cumulative
					sel.merge items
				end
			when /^([+-]?)(?:([1-9]\d*)-([1-9]\d*))$/
				i = $2.to_i - 1
				j = $3.to_i - 1
				raise OggAlbumTagger::ArgumentError, "Range #{$2}-#{$3} is invalid" if i >= all_files.length or j >= all_files.length or i > j

				items = all_files.slice(i..j)
				case $1
				when '-'
					sel.subtract items
					mode = :cumulative
				when '+'
					sel.merge items
					mode = :cumulative
				else
					raise OggAlbumTagger::ArgumentError, "Cannot use the \"#{selector}\" selector after a cumulative selector (+/-...)" if mode == :cumulative
					sel.merge items
				end
			else
				raise OggAlbumTagger::ArgumentError, "Unknown selector \"#{selector}\"."
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

	# Test if a tag is used at least one time in an ogg file.
	def tag_used?(tag)
		values = @selected_files.map { |file| @files[file][tag] }
		values.reduce(false) { |r, v| r || v.size > 0 }
	end

	# Test if a tag is used k times on each selected files.
	def tag_used_k_times?(tag, k)
		self.validate_tag(tag) { |v| v.size == k }
	end

	# Test if a tag is used once on each selected files.
	def tag_used_once?(tag)
		self.tag_used_k_times?(tag, 1)
	end

	# Test if a tag has multiple values in a single file.
	def tag_used_multiple_times?(tag)
		values = @selected_files.map { |file| @files[file][tag] }
		values.reduce(false) { |r, v| r || v.size > 1 }
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
		validate_tag(tag) { |v| (v.size == 0) || (v.first.to_s =~ /^[1-9][0-9]*$/) }
	end

	def date_tag?(tag)
		validate_tag(tag) { |v| (v.size == 0) || (v.first.to_s =~ /^\d\d\d\d$/) }
	end

	# Verify that the library is properly tagged.
	#
	# * ARTIST, TITLE and DATE must be used once per file.
	# * TRACKNUMBER must be used once on an album/compilation.
	# * DATE must be a valid date.
	# * ALBUM must be uniq.
	# * ALBUMARTIST should have the value "Various artists" on a compilation.
	# * ALBUMDATE must be uniq if DATE is not.
	# * DISCNUMBER must be used at most one time per file.
	# * TRACKNUMBER and DISCNUMBER must have numerical values.
	def check
		%w{ARTIST TITLE DATE ALBUM ALBUMDATE ARTISTALBUM TRACKNUMBER DISCNUMBER}.each do |t|
			raise OggAlbumTagger::MetadataError, "The #{t} tag cannot be used multiple times in a single track." if tag_used_multiple_times?(t)
		end

		%w{DISCNUMBER TRACKNUMBER}.each do |t|
			raise OggAlbumTagger::MetadataError, "If used, the #{t} tag must have a numeric value." unless numeric_tag?(t)
		end

		%w{DATE ALBUMDATE}.each do |t|
			raise OggAlbumTagger::MetadataError, "If used, the #{t} tag must be a valid year." unless date_tag?(t)
		end

		once_tags = %w{ARTIST TITLE DATE}
		once_tags << "TRACKNUMBER" unless @path.nil?
		once_tags.each do |t|
			raise OggAlbumTagger::MetadataError, "The #{t} tag must be used once per track." unless tag_used_once?(t)
		end

		return if @path.nil?

		raise OggAlbumTagger::MetadataError, "The ALBUM tag must have a single and uniq value among all songs." unless uniq_tag?('ALBUM')

		if uniq_tag?('ARTIST')
			raise OggAlbumTagger::MetadataError, 'The ALBUMARTIST is only required for compilations.' if tag_used?('ALBUMARTIST')
		else
			if not uniq_tag?('ALBUMARTIST') or (first_value('ALBUMARTIST') != 'Various artists')
				raise OggAlbumTagger::MetadataError, 'This album seems to be a compilation. The ALBUMARTIST tag should have the value "Various artists".'
			end
		end

		raise OggAlbumTagger::MetadataError, "The ALBUMDATE tag must have a single and uniq value among all songs." if not uniq_tag?('DATE') and not uniq_tag?('ALBUMDATE')
	end

	# Auto rename the directory and the ogg files of the library.
	#
	# For singles, the format is:
	# Directory: N/A
	# Ogg file: ARTIST - TITLE (DATE)
	#
	# For an album, the format is:
	# Directory: ARTIST - DATE - ALBUM
	# Ogg file:  ARTIST - DATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE
	#
	# For a single-artist compilation (an album where tracks have different dates), the format is:
	# Directory: ARTIST - ALBUMDATE - ALBUM
	# Ogg file:  ARTIST - ALBUMDATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE - DATE
	#
	# For a compilation, the format is:
	# Directory: ALBUM - ALBUMDATE
	# Ogg file:  ALBUM - ALBUMDATE - [DISCNUMBER.]TRACKNUMBER - ARTIST - TITLE - DATE
	#
	# Disc and track numbers are padded with zeros.
	def auto_rename
		check()

		mapping = {}

		if @path.nil?
			@selected_files.each do |file|
				tags = @files[file]
				mapping[file] = sprintf('%s - %s (%s).ogg', tags.first('ARTIST'), tags.first('TITLE'), tags.first('DATE'))
			end
		else
			tn_maxlength = tag_summary('TRACKNUMBER').values.map { |v| v.first.to_s.length }.max
			tn_format = '%0' + tn_maxlength.to_s + 'd'

			has_discnumber = tag_used_once?('DISCNUMBER')
			if has_discnumber
				dn_maxlength = tag_summary('DISCNUMBER').values.map { |v| v.first.to_s.length }.max
				dn_format = '%0' + dn_maxlength.to_s + 'd'
			end

			format_number = lambda do |tags|
				s = ''
				if has_discnumber
					s += sprintf(dn_format, tags.first('DISCNUMBER').to_i) + '.'
				end
				s += sprintf(tn_format, tags.first('TRACKNUMBER').to_i)
			end

			album_date = uniq_tag?('DATE') ? first_value('DATE') : first_value('ALBUMDATE')

			if uniq_tag?('ARTIST')
				@selected_files.each do |file|
					tags = @files[file]

					common_tags = [tags.first('ARTIST'), album_date, tags.first('ALBUM'),
					               format_number.call(tags), tags.first('TITLE')]

					mapping[file] = if uniq_tag?('DATE')
						sprintf('%s - %s - %s - %s - %s.ogg', *common_tags)
					else
						sprintf('%s - %s - %s - %s - %s - %s.ogg', *common_tags, tags.first('DATE'))
					end
				end

				albumdir = sprintf('%s - %s - %s',
				                   first_value('ARTIST'),
				                   album_date,
				                   first_value('ALBUM'))
			else
				@selected_files.each do |file|
					tags = @files[file]
					mapping[file] = sprintf('%s - %s - %s - %s - %s.ogg',
					                        tags.first('ALBUM'), album_date, format_number.call(tags),
					                        tags.first('ARTIST'), tags.first('TITLE'), tags.first('DATE'))
				end

				albumdir = sprintf('%s - %s', first_value('ALBUM'), album_date)
			end

			albumdir = albumdir.gsub(/[\\\/:*?"<>|]/, '')
		end

		# TODO Should UTF-8 chars be converted to latin1 in order to have Windows-safe filenames?
		mapping.each { |k, v| mapping[k] = v.gsub(/[\\\/:*?"<>|]/, '') }

		if mapping.values.uniq.size != @selected_files.size
			raise OggAlbumTagger::MetadataError, 'Generated filenames are not uniq.'
		end

		# Renaming the album directory
		unless @path.nil?
			begin
				newpath = @path.dirname + albumdir
				if @path.expand_path != newpath.expand_path
					FileUtils.mv(@path, newpath)
					@path = newpath
				end
			rescue Exception => ex
				raise OggAlbumTagger::SystemError, "Cannot rename \"#{@path}\" to \"#{newpath}\"."
			end
		end

		# Renaming the ogg files
		Set.new(@selected_files).each do |file|
			begin
				oldpath = fullpath(file)
				newpath = (@path.nil? ? file.dirname : @path) + mapping[file]

				if oldpath != newpath
					FileUtils.mv(oldpath, newpath)
					@files[newpath] = @files.delete(file)
					@selected_files.delete(file).add(newpath)
				end
			rescue Exception => ex
				raise OggAlbumTagger::SystemError, "Cannot rename \"#{file}\" to \"#{mapping[file]}\"."
			end
		end
	end
end

end

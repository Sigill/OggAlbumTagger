require 'ogg_album_tagger/version'
require 'ogg_album_tagger/tag_container'
require 'ogg_album_tagger/exceptions'

require 'set'
require 'fileutils'

module OggAlbumTagger

# A Library is just a hash associating each ogg file to a TagContainer.
# A subset of file can be selected in order to be tagged.
class Library
	attr_reader :path
	attr_reader :selected_files

	# Build a Library from a list of TagContainer.
	#
	# dir:: The name of the directory supposed to contain all the files. Pass any name if the
	#       tracks of that library are related, +nil+ otherwise.
	# containers:: A hash mapping the files to the containers.
	def initialize dir, tracks
		@path = dir

		@files = tracks.map { |e| e }

		@selected_files = @files.slice(0, @files.size).to_set
	end

	# Return the number of files in this library.
	def size
		@files.size
	end

	# Returns the list of the tags used in the selected files.
	def tags_used
		s = Set.new
		@selected_files.each do |file|
			s.merge file.tags
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

		@files.each_with_index { |file, i|
			next unless @selected_files.include? file

			file.each do |tag, values|
				next unless selected_tag.nil? or tag.eql?(selected_tag)
				data[tag][i] = values.sort
			end
		}

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
			file.write(file.path)
		end
	end

	# Tags the selected files with the specified values.
	#
	# Any previous value will be removed.
	def set_tag(tag, *values)
		tag.upcase!
		@selected_files.each { |file| file.set_values(tag, *values) }
		self
	end

	# Tags the selected files with the specified values.
	def add_tag(tag, *values)
		tag.upcase!
		@selected_files.each { |file| file.add_values(tag, *values) }
		self
	end

	# Remove the specified values from the selected files.
	#
	# If no value is specified, the tag will be removed.
	def rm_tag(tag, *values)
		tag.upcase!
		@selected_files.each { |file| file.rm_values(tag, *values) }
		self
	end

	# Return a list of the files in the library.
	def ls
		@files.each_with_index.map do |file, i|
			{ file: (@path.nil? ? file.path : file.path.relative_path_from(@path)).to_s, selected: @selected_files.include?(file) }
		end
	end

	# Build a Set representing the selected files specified by the selectors.
	#
	# The available selector are:
	# * "all": all files.
	# * "3": the third file.
	# * "5-7": the files 5, 6 and 7.
	#
	# The two last selector can be prefixed by "+" or "-" in order to add or remove items
	# from the current selection. They are called cumulative selectors.
	#
	# Non-cumulative selectors cannot be specified after a cumulative one.
	def build_selection(selectors)
		return @selected_files if selectors.empty?

		mode = :absolute

		first_rel = !!(selectors.first =~ /^[+-]/)

		sel = first_rel ? Set.new(@selected_files) : Set.new

		selectors.each do |selector|
			case selector
			when 'all'
				raise OggAlbumTagger::ArgumentError, "Cannot use the \"#{selector}\" selector after a cumulative selector (+/-...)" if mode == :cumulative
				sel.replace @files
			when /^([+-]?)([1-9]\d*)$/
				i = $2.to_i - 1
				raise OggAlbumTagger::ArgumentError, "Item #{$2} is out of range" if i >= @files.size

				items = [@files.slice(i)]
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
				raise OggAlbumTagger::ArgumentError, "Range #{$2}-#{$3} is invalid" if i >= @files.size or j >= @files.size or i > j

				items = @files.slice(i..j)
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

		return sel
	end

	# Modify the list of selected files.
	def select(args)
		@selected_files.replace(build_selection(args))

		return self
	end

	def with_selection(selectors)
		begin
			previous_selection = Set.new(@selected_files)
			@selected_files = build_selection(selectors)
			yield
		ensure
			@selected_files = previous_selection
		end
	end

	def move(from, to)
		raise ::IndexError, "Invalid from index #{from}" unless (0...@files.size).include?(from)
		raise ::IndexError, "Invalid to index #{to}"     unless (0..@files.size).include?(to)

		# Moving item N before item N does nothing
		# Just like moving item N before item N+1
		return if to == from or to == from + 1

		item = @files.delete_at(from)
		@files.insert(from < to ? to - 1 : to, item)
	end

	# Automatically set the TRACKNUMBER tag of the selected files based on their position in the selection.
	def auto_tracknumber
		i = 0
		@files.each { |file|
			next unless @selected_files.include? file
			file.set_values('TRACKNUMBER', (i+1).to_s)
			i += 1
		}
	end

	# Test if a tag satisfy a predicate on each selected files.
	def validate_tag(tag)
		values = @selected_files.map { |file| file[tag] }
		values.reduce(true) { |r, v| r && yield(v) }
	end

	# Test if a tag is used at least one time in an ogg file.
	def tag_used?(tag)
		values = @selected_files.map { |file| file[tag] }
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

	# Test if at least one of the files has multiple values for the specified tag..
	def tag_used_multiple_times?(tag)
		values = @selected_files.map { |file| file[tag] }
		values.reduce(false) { |r, v| r || (v.size > 1) }
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
		values = @selected_files.map { |file| file[tag] }
		values.reduce(true) { |r, v| r && (v.size == 1) } && (values.map { |v| v.first }.uniq.length == 1)
	end

	# Test if a tag holds a numerical value > 0.
	def numeric_tag?(tag)
		validate_tag(tag) { |v| (v.size == 0) || (v.first.to_s =~ /^[1-9][0-9]*$/) }
	end

	# TODO ISO 8601 compliance (http://www.cl.cam.ac.uk/~mgk25/iso-time.html)
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
	# * ALBUMDATE must be unique. It is not required if DATE is unique.
	# * DISCNUMBER must be used at most one time per file.
	# * TRACKNUMBER and DISCNUMBER must have numerical values.
	def check
		# Catch all the tags that cannot have multiple values.
		%w{ARTIST TITLE DATE ALBUM ALBUMDATE ARTISTALBUM TRACKNUMBER DISCNUMBER}.each do |t|
			raise OggAlbumTagger::MetadataError, "The #{t} tag must not appear more than once per track." if tag_used_multiple_times?(t)
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

		raise OggAlbumTagger::MetadataError, "The ALBUM tag must have a single and unique value among all songs." unless uniq_tag?('ALBUM')

		if tag_used?('ALBUMDATE')
			unless uniq_tag?('ALBUMDATE')
				raise OggAlbumTagger::MetadataError, "The ALBUMDATE tag must have a single and unique value among all songs."
			end

			if uniq_tag?('DATE') && first_value('DATE') == first_value('ALBUMDATE')
				raise OggAlbumTagger::MetadataError, "The ALBUMDATE tag is not required since it is unique and identical to the DATE tag."
			end
		else
			unless uniq_tag?('DATE')
				raise OggAlbumTagger::MetadataError, "The ALBUMDATE tag is required."
			end
		end

		if @selected_files.size == 1
			raise OggAlbumTagger::MetadataError, 'This album has only one track. The consistency of some tags cannot be verified.'
		end

		if uniq_tag?('ARTIST')
			if tag_used?('ALBUMARTIST')
				raise OggAlbumTagger::MetadataError, 'The ALBUMARTIST is not required since all tracks have the same and unique ARTIST.'
			end
		else
			if not uniq_tag?('ALBUMARTIST') or (first_value('ALBUMARTIST') != 'Various artists')
				raise OggAlbumTagger::MetadataError, 'This album seems to be a compilation. The ALBUMARTIST tag should have the value "Various artists".'
			end
		end
	end

	# Auto rename the directory and the ogg files of the library.
	#
	# For singles, the format is:
	# Directory: N/A
	# Ogg file: ARTIST - DATE - TITLE
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
	# Directory: ALBUM - ALBUMDATE|DATE
	# Ogg file:  ALBUM - ALBUMDATE|DATE - [DISCNUMBER.]TRACKNUMBER - ARTIST - TITLE - DATE
	#
	# Disc and track numbers are padded with zeros.

	def compute_rename_mapping
		check()

		mapping = {}

		if @path.nil?
			@selected_files.each do |file|
				mapping[file] = sprintf('%s - %s - %s.ogg', file.first('ARTIST'), file.first('DATE'), file.first('TITLE'))
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

			album_date = tag_used?('ALBUMDATE') ? first_value('ALBUMDATE') : first_value('DATE')

			if uniq_tag?('ARTIST')
				@selected_files.each do |file|
					common_tags = [file.first('ARTIST'), album_date, file.first('ALBUM'),
					               format_number.call(file), file.first('TITLE')]

					mapping[file] = if uniq_tag?('DATE')
						sprintf('%s - %s - %s - %s - %s.ogg', *common_tags)
					else
						sprintf('%s - %s - %s - %s - %s - %s.ogg', *common_tags, file.first('DATE'))
					end
				end

				albumdir = sprintf('%s - %s - %s',
				                   first_value('ARTIST'),
				                   album_date,
				                   first_value('ALBUM'))
			else
				@selected_files.each do |file|
					mapping[file] = sprintf('%s - %s - %s - %s - %s - %s.ogg',
					                        file.first('ALBUM'), album_date, format_number.call(file),
					                        file.first('ARTIST'), file.first('TITLE'), file.first('DATE'))
				end

				albumdir = sprintf('%s - %s', first_value('ALBUM'), album_date)
			end

			albumdir = albumdir.gsub(/[\\\/:*?"<>|]/, '').gsub(/\s+/, ' ')
		end

		# TODO Should UTF-8 chars be converted to latin1 in order to have Windows-safe filenames?
		mapping.each { |k, v| mapping[k] = v.gsub(/[\\\/:*?"<>|]/, '').gsub(/\s+/, ' ') }

		if mapping.values.uniq.size != @selected_files.size
			raise OggAlbumTagger::MetadataError, 'Generated filenames are not unique.'
		end

		newpath = @path.nil? ? nil : @path.dirname.join(albumdir).cleanpath

		return newpath, mapping
	end

	def short_path(file)
		@path.nil? ? file : file.relative_path_from(@path)
	end

	def auto_rename
		newpath, mapping = compute_rename_mapping

		# Renaming the ogg files
		Set.new(@selected_files).each do |file|
			begin
				oldfilepath = file.path
				newfilepath = (@path.nil? ? oldfilepath.dirname : @path).join(mapping[file]).cleanpath

				# Don't rename anything if there's no change.
				if oldfilepath != newfilepath
					rename(oldfilepath, newfilepath)
					file.path = newfilepath
				end
			rescue Exception
				raise OggAlbumTagger::SystemError, "Cannot rename \"#{short_path(oldfilepath)}\" to \"#{short_path(newfilepath)}\"."
			end
		end

		# Renaming the album directory
		unless @path.nil?
			oldpath = @path

			begin
				# Don't rename anything if there's no change.
				if @path != newpath
					rename(@path, newpath)
					@path = newpath

					@files.each { |file|
						newfilepath = newpath + file.path.relative_path_from(oldpath)

						file.path = newfilepath
					}
				end
			rescue Exception
				raise OggAlbumTagger::SystemError, "Cannot rename \"#{oldpath}\" to \"#{newpath}\"."
			end
		end
	end

	def rename(oldpath, newpath)
		FileUtils.mv(oldpath, newpath)
	end
end

end

require 'base64'
require 'exiftool'

module OggAlbumTagger

class Picture
	# Embed a picture so that it can be included as a tag.
	#
	# See http://xiph.org/flac/format.html#metadata_block_picture
	# Note: the type of the picture is currently fixed to "Front cover",
	# as it is the most common type.
	def self.generate_metadata_block_picture(image, desc = '')
		begin
			image = File.expand_path(image)
			img = Exiftool.new(image)
			content = IO.binread(image)
		rescue
			raise ArgumentError, "\"#{image}\" cannot be read."
		end

		meta = img.results[0].to_hash
		mime = meta[:mime_type]

		raise ArgumentError, 'Unsupported image type. Use JPEG or PNG.' unless ['image/png', 'image/jpeg'].include?(mime)

		pack = [
			3, # Front cover
			mime.length,
			mime,
			desc.bytesize,
			desc,
			meta[:image_width],
			meta[:image_height],
			meta[:color_components] * meta[:bits_per_sample],
			0, # palette
			content.length,
			content
		].pack(sprintf("L>L>A%dL>a%dL>L>L>L>L>a*", mime.length, desc.bytesize))
		Base64.strict_encode64(pack)
	end
end

end

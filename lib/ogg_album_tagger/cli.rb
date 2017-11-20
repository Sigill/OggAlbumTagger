require 'readline'
require 'shellwords'

require 'ogg_album_tagger/exceptions'
require 'ogg_album_tagger/picture'

module OggAlbumTagger


class CLI
    QUOTE_CHARACTERS = "\"'"

    def initialize(library)
        @library = library
    end

    def configure_readline
        Readline.completer_quote_characters = QUOTE_CHARACTERS
        Readline.completion_append_character = " "
    end

    SIMPLE_SELECTOR = /^[+-]?[1-9]\d*$/
    RANGE_SELECTOR = /^[+-]?[1-9]\d*-[1-9]\d*$/

    def selector?(arg)
        return arg == 'all' || arg.match(SIMPLE_SELECTOR) || arg.match(RANGE_SELECTOR)
    end

    def autocomplete(buffer, point, input)
        # Extract the context: everything before the word being completed.
        context = buffer.slice(0, point - input.length)

        begin
            # Let's try to split the context into its various arguments.
            context_args = Shellwords.shellwords(context)

            # If the last argument is quoted and the quote is the last character of the context,
            # no autocompletion, or we may end up with things like "something"somethingelse.
            return [] if context.size > 0 and QUOTE_CHARACTERS.include?(context[-1])
        rescue ::ArgumentError => ex
            # The context couldn't be parsed because it ends with an opening quote.
            # Let's remove it to allow the context to be parsed.
            context.slice!(-1) if context.size > 0 and QUOTE_CHARACTERS.include?(context[-1])
            begin
                context_args = Shellwords.shellwords(context)
            rescue ::ArgumentError => ex
                return []
            end
        end

        # Remove leading selectors
        first_not_selector = context_args.find_index { |e| !selector?(e) }
        context_args.slice!(0, first_not_selector) unless first_not_selector.nil? || first_not_selector == 0

        # Keep only suggestions starting with the input.
        sugg = suggestions(context_args, input).grep(/^#{Regexp.escape(input)}/i).map { |v|
            # Quote them if they contain spaces, otherwise a multiple word value
            # will appear unquoted on the command line.
            v.include?(' ') ? "\"#{v}\"" : v
        }
        sugg
    end

    def suggestions(context, input)
        if context.empty?
            # No args, suggest the supported commands.
            return %w{ls select show set add rm auto check write help exit quit}
        elsif %w{ls select check help exit quit}.include?(context[0])
            # These commands don't take any argument or don't need autocomplete.
        elsif context[0] == 'show'
            # The "show" command can be followed by a tag
            return @library.tags_used if context.size == 1
        elsif %w{add set}.include?(context[0])
            case context.size
            when 1
                # The "add" and "set" commands must be followed by a tag.
                # TODO Suggest usual ogg tags.
                return @library.tags_used
            when 2
                if %w{METADATA_BLOCK_PICTURE PICTURE}.include? context[1].upcase
                    # When a picture tag is edited, the tag must be followed by the path of a file.
                    return Readline::FILENAME_COMPLETION_PROC.call(input) || []
                else
                    # Otherwise, propose values already used by the specified tag.
                    return @library.tag_summary(context[1].upcase).values.flatten.uniq
                end
            end
        elsif context[0] == 'rm'
            if context.size == 1
                return @library.tags_used
            else
                tag = context[1].upcase
                if tag == 'METADATA_BLOCK_PICTURE'
                    $stderr.puts
                    $stderr.puts "Autocompletion is not supported for pictures"
                    Readline.refresh_line
                else return @library.tag_summary(tag).values.flatten.uniq
                end
            end
        elsif context[0] == 'auto'
            if context.length == 1
                return %w{tracknumber rename}
            end
        end

        return []
    end

    def print_album_summary(summary)
        OggAlbumTagger::OggFile.sorted_tags(summary.keys) do |tag|
            puts tag

            if (summary[tag].size == @library.selected_files.size) && (summary[tag].values.uniq.length == 1)
                # If all tracks have only one common value
                puts "\t" + OggAlbumTagger::TagContainer::pp_tag(summary[tag].first[1])
            else
                summary[tag].keys.sort.each do |i|
                    values = summary[tag][i]
                    puts sprintf("\t%4d: %s", i+1, OggAlbumTagger::TagContainer::pp_tag(values))
                end
            end
        end
    end

    def show_command(args)
        case args.length
        when 0
            print_album_summary(@library.summary)
        else
            print_album_summary @library.summary(args[0].upcase)
        end
    end

    def ls_command
        @library.ls().each do |f|
            puts sprintf("%s %4d: %s", (f[:selected] ? '*' : ' '), f[:position], f[:file])
        end
    end

    def handle_picture_args args
        if %w{METADATA_BLOCK_PICTURE PICTURE}.include? args[0].upcase
            file = args[1]
            desc = args.length == 2 ? args[1] : ''
            args.clear
            args << 'METADATA_BLOCK_PICTURE'
            args << OggAlbumTagger::Picture::generate_metadata_block_picture(file, desc)
        end
    end

    def parse_command(command_line)
        begin
            arguments = Shellwords.shellwords(command_line)
        rescue ::StandardError => ex
            raise OggAlbumTagger::ArgumentError, "Invalid command."
        end

        selectors = []

        first_not_selector = arguments.find_index { |e| !selector?(e) }
        unless first_not_selector.nil? || first_not_selector == 0
            selectors = arguments.slice!(0, first_not_selector)
        end

        command, *args = arguments

        return selectors, command, args
    end

    def execute_command(command_line)
        selectors, command, args = parse_command(command_line)

        return if command.nil?

        @library.with_selection(selectors) {
            case command
            when 'ls' then ls_command()
            when 'select'
                if args.length < 1
                    puts 'You need to specify the files you want to select. Either enter "all", a single number or a range (ex. "3-5").', 'Number and range based selections can be made cumulative by adding a plus or minus sign in front of the selector (ex. "-1-3").'
                else
                    @library.select(args)
                    ls_command()
                end
            when 'show' then show_command(args)
            when 'set'
                if args.length < 2
                    puts 'You need to specify the tag to edit and at least one value.'
                else
                    handle_picture_args(args)
                    @library.set_tag(*args)
                    show_command([args[0]])
                end
            when 'add'
                if args.length < 2
                    puts 'You need to specify the tag to edit and at least one value.'
                else
                    handle_picture_args(args)
                    @library.add_tag(*args)
                    show_command([args[0]])
                end
            when 'rm'
                if args.length < 1
                    puts 'You need to specify the tag to edit and eventually one or several values.'
                else
                    @library.rm_tag(*args)
                    show_command([args[0]])
                end
            when 'auto'
                if args.length < 1
                    puts 'You need to specify the auto command you want to execute.'
                else
                    case args[0]
                    when 'tracknumber' then @library.auto_tracknumber()
                    when 'rename'
                        @library.auto_rename
                        ls_command()
                    end
                end
            when 'check'
                @library.check
                puts "OK"
            when 'write'
                @library.write
            when 'help'
                # TODO
            else
                puts "Unknown command \"#{command}\""
            end
        }
    end
end

end # module OggAlbumTagger
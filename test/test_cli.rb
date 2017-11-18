require 'minitest/autorun'
require 'set'
require 'readline'
require 'tempfile'
require 'fileutils'
require 'pathname'
require 'ogg_album_tagger/cli'

require 'library_helper'

# Helper method that build a TagContainer object from the specified tags.
def ogg(tags = {})
    OggAlbumTagger::TagContainer.new(tags)
end

# Borrowed from ruby sources
# test/readline/test_readline.rb
def with_temp_stdio
    Tempfile.create("test_readline_stdin") { |stdin|
        Tempfile.create("test_readline_stdout") { |stdout|
            yield stdin, stdout
        }
    }
end

# Borrowed from ruby sources
# test/readline/test_readline.rb
def replace_stdio(stdin_path, stdout_path)
    open(stdin_path, "r") { |stdin|
        open(stdout_path, "w") { |stdout|
            Readline.input = stdin
            Readline.output = stdout
            yield
            Readline.input = STDIN
            Readline.output = STDOUT
        }
    }
end

def with_readline_env
    # Backup the values
    # cqc cannot be restored
    cqc = Readline.completer_quote_characters || "'\""
    cac = Readline.completion_append_character

    begin
        Readline.completer_quote_characters = "\"'"
        Readline.completion_append_character = " "

        yield
    ensure
        Readline.completer_quote_characters = cqc
        Readline.completion_append_character = cac
    end
end

module Minitest::Assertions
    # Assertion used to verify the parameters passed to the completion proc.
    #
    # command:: The command entered in the command line, with a "\t" where
    #           the completion is triggered.
    # exp:: The parameters expected to be passed to the completion proc.
    #       It is composed of 3 parameters: the line buffer, the position
    #       of the cursor, and the entry being autocompleted.
    def assert_autocomplete_args(command, exp)
        mock = Minitest::Mock.new.expect('nil?', false).expect(:autocomplete, [], exp)
        Readline.completion_proc = ->(input) { mock.autocomplete(Readline.line_buffer, Readline.point, input) }

        with_temp_stdio { |stdin, stdout|
            stdin.write(command)
            stdin.flush

            replace_stdio(stdin.path, stdout.path) {
                Readline.readline("> ", false)
            }
        }
    end

    # Assertion used to verify the suggestions proposed by CLI::autocomplete.
    #
    # Readline will be used within a safe environment (stdin/stdio replaced by temporary files),
    # which means byebug, who internally use Readline, cannot be used to debug the completion proc.
    def assert_autocomplete(cli, command, exp)
        suggestions = nil

        Readline.completion_proc = ->(input) {
            suggestions = cli.autocomplete(Readline.line_buffer, Readline.point, input)
        }

        with_temp_stdio { |stdin, stdout|
            stdin.write(command)
            stdin.flush

            replace_stdio(stdin.path, stdout.path) { Readline.readline("> ", false) }
        }

        assert_equal exp, suggestions
    end

    # Assertion used to verify the suggestions proposed by CLI::autocomplete.
    #
    # Readline is only used to retrieve the parameters that will be passed to the completion proc.
    # The completion proc is the tested using these parameters, without needing Readline.
    def assert_cmd_autocomplete(cli, command, exp)
        args = nil

        # Retrieve the args Readline will pass to the completion proc.
        Readline.completion_proc = ->(input) {
            args = [Readline.line_buffer, Readline.point, input]
            return []
        }

        with_temp_stdio { |stdin, stdout|
            stdin.write(command)
            stdin.flush

            replace_stdio(stdin.path, stdout.path) { Readline.readline("> ", false) }
        }

        # Now test the completion proc.
        assert_equal exp, cli.autocomplete(*args)
    end
end

class CLITest < Minitest::Test
    DIR = Pathname.new("/foo/bar").freeze
    A = (DIR + "a.ogg").freeze
    B = (DIR + "b.ogg").freeze
    C = (DIR + "c.ogg").freeze
    D = (DIR + "d.ogg").freeze

    def setup
        @a = ogg(artist: "Alice", album: "This album")
        @b = ogg(artist: "Bob", album: "That album", genre: %w{Pop Rock})
        @lib = TestingLibrary.new(nil, A => @a, B => @b)
        @cli = OggAlbumTagger::CLI.new(@lib)

        # Setup readline
        @cli.configure_readline
    end

    def test_autocomplete_no_command
        assert_cmd_autocomplete @cli, "\t", %w{ls select show set add rm auto check write help exit quit}
    end

    def test_autocomplete_partial_command
        assert_cmd_autocomplete @cli, "se\t", %w{select set}
    end

    # Make sure no autocompletion is done if the last argument is quoted but is not followed by a space.
    def test_no_autocomplete_if_no_space_after_closing_quote
        assert_cmd_autocomplete @cli, "\"add\"\t", []
    end

    def test_autocomplete_ls_select_check_help_exit_quit
        assert_cmd_autocomplete @cli, "ls \t", []
    end


    def test_autocomplete_show
        assert_cmd_autocomplete @cli, "show \t", %w{tag}
    end

    def test_autocomplete_show2
        assert_cmd_autocomplete @cli, "show tag \t", %w{artist album genre}
    end


    def test_autocomplete_add_set
        assert_cmd_autocomplete @cli, "add \t", %w{artist album genre}
    end

    def test_autocomplete_add_set2
        assert_cmd_autocomplete @cli, "set artist \t", %w{Alice Bob}
    end

    def test_autocomplete_add_set_picture
        Dir.mktmpdir { |tmpdir|
            FileUtils.cp("test/data/lena.jpg", tmpdir)
            Dir.chdir(tmpdir) {
                assert_cmd_autocomplete @cli, "set picture \t", %w{lena.jpg}
            }
        }
    end

    def test_autocomplete_add_set_picture2
        Dir.mktmpdir { |tmpdir|
            tmpdir = Pathname.new(tmpdir)
            FileUtils.cp("test/data/lena.jpg", tmpdir)
            assert_cmd_autocomplete @cli, "set picture #{(tmpdir + "le").to_s}\t", [(tmpdir + "lena.jpg").to_s]
        }
    end

    def test_autocomplete_add_set_picture2
        Dir.mktmpdir { |tmpdir|
            Dir.chdir(tmpdir) {
                assert_cmd_autocomplete @cli, "set picture missing\t", []
            }
        }
    end

    # Make sure suggestions containing spaces are quoted.
    def test_autocomplete_quote_space
        assert_cmd_autocomplete @cli, "add album \t", ['"This album"', '"That album"']
    end

    def test_autocomplete_quote_space2
        assert_cmd_autocomplete @cli, "add album This\t", ['"This album"']
    end

    def test_autocomplete_quote_space3
        assert_cmd_autocomplete @cli, "add album \"This\t", ['"This album"']
    end

    def test_autocomplete_quote_space4
        assert_cmd_autocomplete @cli, "add album \"This \t", ['"This album"']
    end


    def test_autocomplete_rm
        assert_cmd_autocomplete @cli, "rm \t", %w{artist album genre}
    end

    def test_autocomplete_rm2
        assert_cmd_autocomplete @cli, "rm genre \t", %w{Pop Rock}
    end

    # Make sure we can specify multiple tag values
    def test_autocomplete_rm3
        assert_cmd_autocomplete @cli, "rm genre Pop \t", %w{Pop Rock}
    end


    def test_autocomplete_auto
        assert_cmd_autocomplete @cli, "auto \t", %w{tracknumber rename}
    end
end
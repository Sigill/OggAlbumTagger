# OggAlbumTagger

[OggAlbumTagger](https://github.com/Sigill/OggAlbumTagger) is a command line tool written in Ruby that allows you to easily and interactively tag Ogg files. It gives you access to all tags, supports multi-valued tags and cover pictures, is able to manage whole albums and can enforce good tagging practices.

## Why OggAlbumTagger

I wanted a tool that would give me a full and easy access to all tags and would integrate some logic to quickly tag full albums or compilations.

Current solutions were not satisfying enough to me:

* No easy way to access non-standard tags.
* No/limited support for tags with multiple values.
* No easy way to tag full albums.
* Unwanted padding of numerical tags.
* No consistency concerning the case and order of the tags (ok, this point might be a bit excessive).

Therefore, I wrote OggAlbumTagger. It is designed to enforce some good tagging practices (you can read about them in the "How to properly tag your music" section below), but it will let you do whatever you want.

## Usage

```
$ ogg-album-tagger [options] files|directories
Options:
    -a, --album    Album mode, treat a single directory as an album.
    -v, --version  Display version information and exit.
    -h, --help     Print this help.
```

When executed, OggAlbumTagger extracts the tags of the ogg files passed as arguments (ogg files will be searched recursively in directories). Once done, you have to use the commands listed below to access and modify the tags.

The album mode (album is used here in a broad sense, we will distinguish album, best-of and compilations later), OggAlbumTagger will require album specific tags, will enforce a few more good tagging practices and will allow you to rename the album directory along with the files. You have to work on a single directory.

### Preliminary notes

* OggAlbumTagger works like most terminals. Arguments need to be separated by one or more spaces. If your argument contains special characters (spaces, single or double quotes), you can either escape them with a backslash (`\`) or enclose your argument with single or double quotes. Inside a double-quoted argument, you can escape double quotes with a backslash. Single-quoted arguments do not support escaping.
* OggAlbumTagger is capable of autocompletion and autosuggestion. Press the `tab` key to autocomplete your arguments, tag names, tag values and filenames. If you don't know what to do, double press `tab` to get suggestions.
* Tag names are case insensitive, but they will be written uppercase in files.
* Each tag can have multiple values (but in order to enforce good tagging practices, OggAlbumTagger will prevent you to do so for some tags).
* OggAlbumTagger uses UTF-8 (but currently I don't know what happen if your terminal is not in UTF-8).

### Available commands

__`ls`__: lists the files you have access to. Files are sorted according to their filename and are indexed by their position in the list. The star at the beginning of a line indicates that the file is selected (see the `select` command for more details).

```
> ls
*    1: Queen - 01 - Bohemian Rapsody.ogg
*    2: Queen - 02 - Another One Bites The Dust.ogg
*    3: Queen - 03 - Killer Queen.ogg
…
```

__`select arg1 [arg2…]`__: allow to select a subset of files to work on. The following selectors are available:

* `all`: selects all the files.
* `i`: selects the file at position `i` in the list.
* `i-j`: selects the files from position `i` to position `j` in the list.

Index-based arguments can be prefixed by a `+` or `-` sign (e.g. `-3` or `+10-20`). In this case your selector will add or remove elements to the current selection.

Multiple selectors can be specified at once. Order is important.

__`show`__: without argument, displays the tags of the selected files. Tags are sorted alphabetically, except for the `metadata_block_picture` which is listed last. The command can be restricted to a single tag XXX by using the `show tag xxx` command.

__`set <tag> value1 [value2…]`__: tags each selected files with the specified tag and all specified values. If the tag does not exist, it is created. If it already exists, all previous values are discarded before adding the new ones. Duplicated values are discarded.

If the tag is `metadata_block_picture` (also aliased as `picture`), you have to provide the path to a jpeg or png file (autocomplete also works here) and optionally a description of the picture. OggAlbumTagger currently only supports the "front cover" type (see http://xiph.org/flac/format.html#metadata_block_picture).

__`add <tag> value1 [value2…]`__: like `set`, but previous values are not discarded.

__`rm <tag> [value1…]`__: removes the specified values of the specified tag for all selected files. If no value is specified, the tag is deleted.

__`check`__: verify that you follow good tagging practices.

__`auto tracknumber`__: automatically sets the `TRACKNUMBER` tag based on the selection. Numbering starts at 1, there is no padding with zeros.

__`auto rename`__: renames the directory and the files based on the tags. The tags must be properly tagged: the `check` command will be automatically executed, and no renaming will take place unless all the files are properly tagged. Different patterns are used:

* Single files
  Directory: N/A
  Ogg files: ARTIST - DATE - TITLE.ogg
* Albums
  Directory: ARTIST - DATE - ALBUM
  Ogg files: ARTIST - DATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE.ogg
* Single artist compilations (albums where tracks have different dates, like a best-of)
  Directory: ARTIST - ALBUMDATE - ALBUM
  Ogg files: ARTIST - ALBUMDATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE - DATE.ogg
* Compilations
  Directory: ALBUM - ALBUMDATE
  Ogg files: ALBUM - ALBUMDATE - [DISCNUMBER.]TRACKNUMBER - ARTIST - DATE - TITLE.ogg

`DISCNUMBER` and `TRACKNUMBER` tags are automatically padded with zeros in order to be of equal length and allow alphabetical sort.

Those characters are not authorized in file names: `\/:*?"<>|`. They will be removed.

In album mode, all ogg files will be moved to the root of the album.

__`write`__: writes the tags in the files.

__`quit`__ or __`exit`__: discards all modifications and closes OggAlbumTagger.

## How to install

First, you need to install:

* The `exiftool` tool.
* The `libtag` (also called `taglib` on some systems) library and its development package.
* The ruby development package (generally called `ruby-dev`).

For example, on Debian/Ubuntu systems, run `apt-get install libimage-exiftool-perl libtag1-dev ruby-dev` from your terminal.

Then, run `gem install ogg_album_tagger`. It will automatically build and install the required Ruby dependencies.

## How to hack/contribute

First, install the required dependencies listed in the "How to install" section above.

Then, install the `rake` and `bundle` gems: `gem install rake bundle`.

Finally, run `bundle install` to install Ruby dependencies.

You will then be able to:

* Run from source: `bundle exec ogg-album-tagger …`.
* Run the tests: `rake test` or `m test/test_something.rb[:line]` to run a subset of tests.
* Install from source: `rake install`.
* Build the gem: `gem build ogg_album_tagger.gemspec`.

## How to properly tag your music

These good practices apply to Vorbis comments (the type of tags used in ogg files). There is nothing official about them, they only describe an efficient way to tag your music.

Always specify the ARTIST, TITLE and DATE (OggAlbumTagger requires a year) tags.

For albums, best-of (same artist, different dates) and compilations (different artists), specify the ALBUM and TRACKNUMBER. If there are multiple discs, use the DISCNUMBER tag. Do not pad numerical tags (TRACKNUMBER, DISCNUMBER) with zeros (if you media player is unable to know that 2 comes before 10, use another media player). If the tracks of your best-of/compilation are composed at different DATEs, use the ALBUMDATE tag.

On compilations (and only compilations), set the ALBUMARTIST tag to "Various artists". This way, you can easily search for compilations in your audio library.

The ALBUM, ARTIST, ALBUMARTIST and TITLE tags are designed for systems with limited display capabilities. When used, they must contain one single value.

You can specify alternate values using the ALBUMSORT, ARTISTSORT, ALBUMARTISTSORT and TITLESORT tags. The ARTISTSORT is especially useful if you want to specify the name of all members of a group (so that searching for John Lennon will give you its performances from The Beatles years and from its experimental period with Yoko Ono), if you want The Beatles to be listed at "B" or Bob Dylan to also be listed as "Dylan, Bob". If your media player does not support these -SORT tags, use another media player.

It's nice to have a GENRE (or several), but don't try to be too precise or too exhaustive, or it might make it harder to search by genre. Use the genres you are able to recognize, add "base" genres (this [list](http://id3.org/id3v2.3.0#Appendix_A_-_Genre_List_from_ID3v1) is a good start) or split "hybrid" genres (like "Pop-Rock").

Other standard/recommended tags: see [this page](http://www.xiph.org/vorbis/doc/v-comment.html) and [this one](http://www.legroom.net/2009/05/09/ogg-vorbis-and-flac-comment-field-recommendations). But you can achieve pretty good tagging using the tags listed above.

## TODO

* Include documentation, using the `--help` option, an `help` command, manpages…
* Enforce UTF-8 usage.
* Make the code modular, so that each available command lives in a single class that handles its own autosuggestion, autocompletion, execution… Ok, it requires rewriting half of the program, but it would be cool.
* Support multiline comments.

The functionalities in the following list don't "have to" be implemented. Personally, I don't need most of them. If you have some time to spare, I'll be happy to accept your contributions.

* Support other audio formats: OggalbumTagger is built upon the [TagLib gem](http://robinst.github.io/taglib-ruby/), which support many audio formats. Theoretically, it is possible to support them in OggAlbumTagger (the name can be changed). In practice, I've no desire to play with those ugly ID3 tags and theirs versions and encodings. If you need this functionnality, it might be quicker for you to convert your music library to ogg (I've done it, no regret).
* Fill tags from filenames or from some CDDB/FreeDB/… database. In the meantime, use [lltags](http://home.gna.org/lltag/).
* Export cover pictures.
* Whatever you feel useful…

## License

This tool is released under the terms of the MIT License. See the LICENSE.txt file for more details.

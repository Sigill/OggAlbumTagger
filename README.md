# OggAlbumTagger

OggAlbumTagger is an interactive command line tool that help you tag ogg files. As the name suggest, OggAlbumTagger is able to manage whole albums and compilations.

## Usage

    $ ogg-album-tagger [options] files|directories
    Options:
        -a, --album    Treat a single directory as an album.
        -h, --help     Print this help.`

When executed, OggAlbumTagger extracts the tags of the ogg files passed as arguments (ogg files will be searched recursively in directories). Once done, you have to use the commands listed below to access and modify the tags.

When the `-a` option is passed, you must work on a single directory. OggAlbumTagger will require album (or compilation) specific tags. When renaming the files, the directory will also be renamed.

### Preliminary notes

- OggAlbumTagger works like most terminals. Arguments need to be separated by one or more spaces. If your argument contains special characters (spaces, single or double quotes), you can either escape them with a backslash (`\`) or enclose you argument with single or double quotes. Inside a double-quoted argument, you can escape double quotes with a backslash. Single-quoted arguments do not support escaping.

- OggAlbumTagger is capable of autocompletion and autosuggestion. Press the `tab` key to autocomplete your arguments, tag names, tag values and filenames. If you don't know what to do, double press `tab` to get suggestions.

- Tag names are case insensitive, but they will be written uppercase in files.

- Each tag can have multiple values. They are displayed and written in files in alphabetical order.

- OggAlbumTagger uses UTF-8 (but currently I don't know what happen if your terminal is not in UTF-8).

### Available commands

- `ls`: lists the files you have access to. Files are sorted according to their filename and are indexed by their position in the list. The star at the beginning of a line indicates that the file is selected (see the `select` command for more details).

```
> ls
*    1: Queen - 1981 - Greatest Hits I - 01 - Bohemian Rapsody (1975).ogg
*    2: Queen - 1981 - Greatest Hits I - 02 - Another One Bites The Dust (1980).ogg
*    3: Queen - 1981 - Greatest Hits I - 03 - Killer Queen (1974).ogg
...
```

- `select arg1 [arg2...]`: allow to select a subset of files to work on. The following selectors are available:
    - `all`: selects all the files.
    - `i`: selects the file at position `i` in the list.
    - `i-j`: selects the files from position `i` to position `j` in the list.

  Index-based arguments can be prefixed by a `+` or `-` sign (e.g. `-3` or `+10-20`). In this case your selector will add or remove elements to the current selection.

  Multiple selectors can be specified at once. Order is important.

- `show`: without argument, displays the tags of the selected files. Tags are sorted alphabetically, except for the `metadata_block_picture` which is listed last. The command can be restricted to a single tag XXX by using the `show tag xxx` command.

- `set <tag> value1 [value2...]`: tags each selected files with the specified tag and all specified values. If the tag does not exists, it is created. If it already exists, all previous values are discarded before adding the new ones. Duplicated values are discarded.

  If the tag is `metadata_block_picture` (also aliased as `picture`), you have to provide the path to a jpeg or png file (autocomplete also works here) and optionally a description for the picture. Currently, `ogg_album_tagger` only supports the "front cover" type (see http://xiph.org/flac/format.html#metadata_block_picture).

- `add <tag> value1 [value2...]`: like `set`, but previous values are not discarded.

- `rm <tag> [value1...]`: removes the specified values of the specified tag for all selected files. If no value is specified, the tag is deleted.

- `auto tracknumber`: automatically sets the `TRACKNUMBER` tag based on the selection. Numbering starts at 1, there is no padding with zeros.

- `auto rename`: renames the directory and the files based on the tags. Different patterns are used:

  - Single files

    Directory: N/A

    Ogg files: ARTIST - TITLE (DATE)

  - Albums

    Directory: ARTIST - DATE - ALBUM

    Ogg files: ARTIST - DATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE.ogg

  - Single artist compilations (albums where tracks have different dates, like a best-of)

    Directory: ARTIST - ALBUMDATE - ALBUM

    Ogg files: ARTIST - ALBUMDATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE - DATE.ogg

  - Compilations

    Directory: ALBUM - ALBUMDATE

    Ogg files: ALBUM - ALBUMDATE - [DISCNUMBER.]TRACKNUMBER - ARTIST - DATE - TITLE.ogg

  `DISCNUMBER` and `TRACKNUMBER` tags are automatically padded with zeros in order to be of equal length and allow alphabetical sort.

  All ogg files will be moved at the root of the album.

- `write`: writes the tags in the files.

- `quit`: closes `ogg_album_tagger`.

## How to install

First, you need to install the `exiftool` tool and `libtag` (sometimes called `taglib` on some systems) library (you need the development package, since the ruby gem will be built upon it). For example, on Debian/Ubuntu systems, run `apt-get install libimage-exiftool-perl libtag1-dev` from your terminal.

### Install from sources

Run `bundle install` to install dependencies.

Run `rake install` to install the gem from the sources.

### Run without installing

From the root of the source folder, run `bundle exec ogg-album-tagger  ...`.

## License

This tool is released under the terms of the MIT License. See the LICENSE.txt file for more details.

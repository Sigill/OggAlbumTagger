# OggAlbumTagger

OggAlbumTagger is an interactive command line tool that help you tag albums and compilations. As the name suggests, it only works with ogg files (it is a wrapper around the vorbiscomment tool).

## Usage

`$ ogg-album-tagger <album directory>`

When executed, ogg-album-editor will recursively find ogg files in the specified directory and extract theirs tags. Once done, you have to use the commands listed below to access and modify the tags.

### Preliminary notes

- `ogg_album_tagger` works like most terminals. Arguments need to be separated by one or more spaces. If your argument contains special characters (spaces, single or double quotes), you can either escape them with a backslash (`\`) or enclose you argument with single or double quotes. Inside a double-quoted argument, you can escape double quotes with a backslash. Single-quoted arguments do not support escaping.
- `ogg_album_tagger` is capable of autocompletion and autosuggestion. Press the `tab` key to autocomplete your arguments, tag names, tag values and file names. If you don't know what to do, double press `tab` to get suggestions.
- Tag names are case insensitive, but they will be written uppercase in files.
- Each tag can have multiple values. They are displayed and written written in files in alphabetical order.
- `ogg_album_tagger` uses UTF-8 (but currently I don't know what happen if your terminal is not in UTF-8).

### Available commands

- `ls`: list the files you have access to. Files are sorted according to their filename. and are indexed by their position in the list. The star at the beginning of a line indicates that the files is selected (see the `select` command for more details).

```
> ls
*    1: Queen - 1981 - Greatest Hits I - 01 - Bohemian Rapsody (1975).ogg
*    2: Queen - 1981 - Greatest Hits I - 02 - Another One Bites The Dust (1980).ogg
*    3: Queen - 1981 - Greatest Hits I - 03 - Killer Queen (1974).ogg
...
```

- `select arg1 [arg2...]`: allow to select a subset of files to work on. You can use the following selectors:

    - `all`: select all the files.
    - `i`: select the file at position `i` in the list.
    - `i-j`: select the files from position `i` to position `j` in the list.

    If you prefix an index-based arguments by a `+` or `-` sign (e.g. "`-3`" or "`+10-20`"), your selector will add or remove elements to the current selection.

    You can specify multiple selectors at once. Order is important.

- `show`: without argument, display the tags of the selected files. Tags are sorted alphabetically, except for the `metadata_block_picture` which is listed last. You can restrict the command to a single tag XXX by using the `show tag xxx` command.
- `set <tag> value1 [value2...]`: tag each selected files with the specified tag and all specified values. If the tag does not exists, it will be created. If it already exists, all previous values will be discarded before adding the provided ones. Duplicated values will be discarded.

    If the tag is `metadata_block_picture` (also aliased as `picture`), you have to provide the path to a jpeg or png file (autocomplete also works here) and optionally a description for the picture. Currently, `ogg_album_tagger` only supports the "front cover" type (see http://xiph.org/flac/format.html#metadata_block_picture).

- `add <tag> value1 [value2...]`: like `set`, but previous values are not discarded.
- `rm <tag> [value1...]`: removes the specified values of the specified tag for all selected files. If no value is specified, the tag is deleted.
- `auto tracknumber`: automatically sets the `TRACKNUMBER` tag based on the selection. Numbering starts at 1, there is no padding with zeros.
- `auto rename`: renames the directory and the files based on the tags. Different patterns are used: 
    - Albums:

        Directory: ARTIST - DATE - ALBUM

        Ogg files: ARTIST - DATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE.ogg

    - Single artist compilations (albums where tracks have different dates, like a best-of):

        Directory: ARTIST - ALBUMDATE - ALBUM

        Ogg files: ARTIST - ALBUMDATE - ALBUM - [DISCNUMBER.]TRACKNUMBER - TITLE - DATE.ogg

    - Compilations:

        Directory: ALBUM - ALBUMDATE

        Ogg files: ALBUM - ALBUMDATE - [DISCNUMBER.]TRACKNUMBER - ARTIST - DATE - TITLE.ogg

    `DISCNUMBER` and `TRACKNUMBER` tags are automatically padded with zeros in order to be of equal length and allow alphabetical sort.

- `write`: write the tags in the files.
- `quit`: closes `ogg_album_tagger`.

## How to install

First, you need to install the exiftool and vorbiscomment tools. For example, on Debian/Ubuntu systems, run `apt-get install vorbis-tools libimage-exiftool-perl` from your terminal.

### Install from sources

Run `bundle install` to install dependencies.

Run `rake install` to install the gem from the sources.

### Run without installing

From the root of the source folder, run `bundle exec ogg-album-tagger <album directory>`.

## License

This tool is released under the terms of the MIT License. See the LICENSE.txt file for more details.

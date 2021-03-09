#!/usr/bin/env python3

import argparse
import base64
import json
import sys
from argparse import RawTextHelpFormatter
from mutagen.oggvorbis import OggVorbis
from mutagen.flac import Picture


def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)


def mbp_to_dict(data):
    data = base64.b64decode(data)
    picture = Picture(data)

    return {'data': base64.b64encode(picture.data).decode("ascii"),
            'type': picture.type,
            'desc': picture.desc,
            'mime': picture.mime,
            'width': picture.width,
            'height': picture.height,
            'depth': picture.depth}


def dict_to_picture(data):
    picture = Picture()
    picture.data = base64.b64decode(data['data'])
    picture.type = data['type']
    picture.desc = data['desc']
    picture.mime = data['mime']
    picture.width = data['width']
    picture.height = data['height']
    picture.depth = data['depth']

    return base64.b64encode(picture.write()).decode("ascii")


def main():
    try:
        parser = argparse.ArgumentParser(description='', formatter_class=RawTextHelpFormatter)

        parser.add_argument('-l', '--list', dest='list', action='store_true',
                            help='')
        parser.add_argument('-w', '--write', dest='write', metavar='<json file>',
                            help='')

        parser.add_argument('file')

        args = parser.parse_args()

        if args.list:
            f = OggVorbis(args.file)
            tags = {}
            for k, v in f.items():
                if k.upper() == 'METADATA_BLOCK_PICTURE':
                    tags[k.upper()] = list(map(lambda pic: mbp_to_dict(pic), v))
                else:
                    tags[k.upper()] = v
            print(json.dumps(tags, indent=4))
        elif args.write:
            with open(args.write, 'r') as json_file:
                data = json.load(json_file)
            f = OggVorbis(args.file)
            f.delete()

            for k, v in data.items():
                if k.upper() == 'METADATA_BLOCK_PICTURE':
                    f[k.upper()] = list(map(lambda pic: dict_to_picture(pic), v))
                else:
                    f[k.upper()] = v

            f.save()

    except ValueError as ex:
        eprint(str(ex))
        exit(-1)


if __name__ == "__main__":
    main()

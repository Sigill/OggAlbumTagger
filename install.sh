#!/bin/bash

[ -f "v1.11.1.tar.gz" ] || wget "https://github.com/taglib/taglib/archive/v1.11.1.tar.gz"
[ -f "v1.12.tar.gz" ] || wget "https://github.com/taglib/taglib/archive/v1.12.tar.gz"

mkdir -p taglib-1.11.1-src/build taglib-1.12-src/build

[ -d "taglib-1.11.1" ] || tar -xzf v1.11.1.tar.gz --strip-components=1 -C "$PWD/taglib-1.11.1-src"
[ -d "taglib-1.12" ] || tar -xzf v1.12.tar.gz --strip-components=1 -C "$PWD/taglib-1.12-src"


# cmake -S "$PWD/taglib-1.11.1-src" -B "$PWD/taglib-1.11.1-src/build" \
#       -DCMAKE_BUILD_TYPE=Release -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_BINDINGS=OFF -DBUILD_SHARED_LIBS=ON \
#       -DWITH_MP4=ON -DWITH_ASF=ON "-DCMAKE_INSTALL_PREFIX=$PWD/taglib-1.11.1"

# cmake --build "$PWD/taglib-1.11.1-src/build" --target install -- -j $(nproc)

# cmake -S "$PWD/taglib-1.12-src" -B "$PWD/taglib-1.12-src/build" \
#       -DCMAKE_BUILD_TYPE=Release -DBUILD_EXAMPLES=OFF -DBUILD_TESTS=OFF -DBUILD_BINDINGS=OFF -DBUILD_SHARED_LIBS=ON \
#       -DWITH_MP4=ON -DWITH_ASF=ON "-DCMAKE_INSTALL_PREFIX=$PWD/taglib-1.12"

# cmake --build "$PWD/taglib-1.12-src/build" --target install -- -j $(nproc)


PLATFORM=x86_64-linux \
TAGLIB_VERSION=1.11.1 \
TAGLIB_DIR=$PWD/taglib-1.11.1 \
LD_LIBRARY_PATH=$PWD/taglib-1.11.1/lib \
bundle install
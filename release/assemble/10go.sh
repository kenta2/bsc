#!/bin/bash
set -xeuv
set -o pipefail
if [ -z "${1-}" ]
then echo "need version"
     exit 1
fi
version=$1
shift

if [ -z "${1-}" ]
then echo "need source"
     exit 1
fi
source=$1
shift

if ! [ -e "$source" ]
then echo "source '$source' does not exist"
     exit 1
fi

if [ -z "${1-}" ]
then echo "need target"
     exit 1
fi
target=$1
shift

mkdir "$target"
d=$(mktemp -d)
for file in "$source"/*.zip
do ln -s "$file" "$d"
done

for file in "$d"/bsc*.zip
do perl rename-from-lxc.pl "$file"
done

ls -l "$d"

mkdir "$d"/doc
master=ubuntu-22.04
unzip "$source"/"$master build doc.zip" -d "$d"/doc
tar xf "$d"/doc/inst.tar.gz -C "$d"
find "$d"/inst -name '*pdf' -exec cp '{}' "$target" \;


for file in "$d"/*build.zip
do bash assemble.sh "$version" "$target" "$file"
done

rm -fr "$d"

pushd "$target"
sha256sum *.gz > SHA256SUM

# todo: yices-src

ls -l "$target"
echo All done $0

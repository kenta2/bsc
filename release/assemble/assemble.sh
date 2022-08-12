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
then echo "need target directory"
     exit 1
fi
target="$1"
shift

if [ -z "${1-}" ]
then echo "need filename"
     exit 1
fi
fullname=$1
dir=$(dirname "$fullname")
name=$(basename "$fullname")
os=${name% build.zip}
if ! [ -e "$dir/$os build.zip" ]
then echo "filename not the correct format"
     exit 1
fi

d=$(mktemp -d)
master=ubuntu-22.04
mkdir "$d"/build "$d"/doc "$d"/releasenotes
unzip "$fullname" -d "$d"/build
unzip $dir/"$master build doc.zip" -d "$d"/doc
unzip $dir/"$master releasenotes.zip" -d "$d"/releasenotes

mkdir "$d"/test
for file in build doc releasenotes
do mkdir "$d"/test/$file
   tar xf "$d/$file/inst.tar.gz" -C "$d"/test/$file
   tar xf "$d/$file/inst.tar.gz" -C "$d"
   pushd "$d"/test/$file
   find . -not -type d > ../$file.list
   popd
done

# make sure there are not collisions of the same file built twice
cat "$d"/test/*.list | sort | uniq -c > "$d"/test/numbers
perl -nlwae 'die $_ unless $F[0]eq"1"' "$d"/test/numbers

tarname="bsc-$version-$os"
mv "$d"/inst "$d/$tarname"
tar cf "$target/$tarname.tar.gz" -C "$d" "$tarname"

rm -fr "$d"
echo All done $0

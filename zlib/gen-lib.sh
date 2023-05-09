#!/bin/bash

BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function setup() {
	apt-get install -y git gcc cmake
	git clone https://github.com/madler/zlib.git $1
}

function build() {
	cp -r "$1" "/tmp/build"
	cd "/tmp/build"
	mkdir -p "$2/lib"
	mkdir -p "$2/share/man/man3"
	mkdir /tmp/build/objs /tmp/build/pics
	if ! ./configure --prefix="$2" --shared ; then
		echo "Configure failed"
		return 1
	fi
	# Bugfix for v1.2.5.1
	GITVERS=$(git describe)
	if [[ "$GITVERS" == "v1.2.5.1" ]] ; then
		make CFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" SFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" SHAREDLIB=libz.so SHAREDLIBV=libz.so.1.2.5.1 SHAREDLIBM=libz.so.1 shared || true
		gcc -O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -o libz.so.1.2.5.1 adler32.lo compress.lo crc32.lo deflate.lo gzclose.lo gzlib.lo gzread.lo gzwrite.lo infback.lo inffast.lo inflate.lo inftrees.lo trees.lo uncompr.lo zutil.lo -shared -lc
		cp libz.so.1.2.5.1 $2/lib/
		ln -s libz.so.1.2.5.1 $2/lib/libz.so
		ln -s libz.so.1.2.5.1 $2/lib/libz.so.1
	else
		make CFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" SFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" shared || true
		if ! make sharedlibdir="$2/lib" CFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" SFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" install; then
			echo "make failed"
			return 1
		fi
		# Fix missing symlink for v1.2.3.4
		if [[ "$GITVERS" == "v1.2.3.4" ]] ; then
			ln -s libz.so $2/lib/libz.so.1
			ln -s libz.so $2/lib/libz.so.1.2.3.4
		fi
	fi

	make clean || true
	cd "$1"
	rm -rf "/tmp/build"
}

source "${BASEDIR}/../tools/generator.sh"




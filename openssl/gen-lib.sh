#!/bin/bash

TESTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function setup() {
	apt-get install -y git gcc make perl libtext-template-perl
	git clone git://git.openssl.org/openssl.git $1
}

function build() {
	# Fix for versions prio to OpenSSL 1.1.0h
	grep -rl "'File::Glob' => qw/glob/;" "$1" | xargs sed -i "s#'File::Glob' => qw/glob/;#'File::Glob' => qw/bsd_glob/;#g"

	mkdir -p "$2"
	mkdir -p "$1/build-tmp"
	cd "$1/build-tmp"
	if ! ../config --prefix="$2" --openssldir="$2" --debug ; then
		echo "Configure failed"
		return 1
	elif ! make ; then
		echo "make failed"
		return 1
#	elif ! make test ; then
#		echo "make test failed"
#		return 1
	elif ! make install ; then
		echo "make install (to $2) failed"
		return 1
	fi
	perl configdata.pm -d > "$2/.configdata" || true
	make clean || true
	cd "$1"
	git checkout .
	rm -rf "$1/build-tmp"
}

source "${TESTDIR}/../tools/generator.sh"


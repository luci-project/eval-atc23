#!/bin/bash

BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function setup() {
	apt-get install -y git gcc cmake automake libtool gettext docbook2x
	git clone https://github.com/libexpat/libexpat.git $1
}

function build() {
	cp -r "$1/expat" "$1/build-tmp"
	cd "$1/build-tmp"
	if ./buildconf.sh 2>&1 | grep " error: " ; then
		echo "buildconf script failed"
		aclocal
		autoheader
		autoconf
	fi
	# Bug in R_2_1_0
	# see https://github.com/libexpat/libexpat/commit/426bb860ccf225bff11be79e15c03cba1f8058fb
	if [[ "$(git rev-parse --short HEAD)" == "62574fc8" ]] ; then
		echo "Bug fix to build R_2_1_0"
		automake --add-missing 2>/dev/null || true
	fi
	mkdir -p "$2"
	if ! ./configure --prefix="$2" ; then
		echo "Configure failed"
		return 1
	elif ! make ; then
		echo "make failed"
		return 1
	fi
	make install || true
	make clean || true
	cd "$1"
	rm -rf "$1/build-tmp"
}

source "${BASEDIR}/../tools/generator.sh"


#!/bin/bash

BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
# Avoid build problems with gcc-10 (bullseye)
IMAGE=debian:buster

function setup() {
	apt-get install -y git gcc make perl autoconf libtool pkgconf
	git clone https://github.com/besser82/libxcrypt $1
}

function build() {
	cp -r "$1" "/tmp/build"
	cd "/tmp/build"
	libtoolize
	aclocal
	autoheader
	autoconf
	automake --add-missing
	if ! ./configure --prefix="$2" --disable-werror ; then
		echo "Configure failed"
		return 1
	elif ! make ; then
		echo "make failed"
		return 1
	elif ! make install ; then
		echo "make install (to $2) failed"
		return 1
	fi
	cd "$1"
	rm -rf "/tmp/build"
}

source "${BASEDIR}/../tools/generator.sh"


#!/bin/bash

BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SKIPEXISTING=false
SUFFIX="-test"
LOGPREFIX="test-build"

function setup() {
	apt-get install -y git gcc make perl autoconf libtool pkgconf
	git clone https://github.com/besser82/libxcrypt "$1"
}

function build() {
	cd "$1"
	libtoolize
	aclocal
	autoheader
	autoconf
	automake --add-missing
	if ! ./configure --disable-werror ; then
		echo "Configure failed"
		return 1
	elif ! make ; then
		echo "make failed"
		return 1
	fi
	TEST_DIR=$(readlink -f "$2/../test")
	mkdir -p "$TEST_DIR"
	cd "$2/../test-src/"
	make CRYPT_SOURCE_DIR=$1 BUILD_DIR=$TEST_DIR -B
	chown -R "$3" "${TEST_DIR}" || true
}

source "${BASEDIR}/../tools/generator.sh"


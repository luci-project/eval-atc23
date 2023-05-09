#!/bin/bash

BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SKIPEXISTING=false
LOGPREFIX="test-build"

function setup() {
	apt-get install -y git gcc make
	git clone https://github.com/madler/zlib.git $1
}

function build() {
	TEST_DIR=$(readlink -f "$2/../test")
	mkdir -p "$TEST_DIR"
	make BUILD_ROOT=$2 TARGET_DIR=$TEST_DIR -C $2/../test-src -B
	chown -R "$3" "${TEST_DIR}" || true
}

source "${BASEDIR}/../tools/generator.sh"


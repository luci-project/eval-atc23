#!/bin/bash

BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SKIPEXISTING=false
LOGPREFIX="test-build"

function setup() {
	apt-get install -y git gcc make libssl-dev
}

function build() {
	TEST_DIR=$(readlink -f "$2/../test")
	mkdir -p "$TEST_DIR"
	make TARGET_DIR="$TEST_DIR"  -C  $2/../src-test/ -B
	chown -R "$3" "${TEST_DIR}" || true
}

source "${BASEDIR}/../tools/generator.sh"

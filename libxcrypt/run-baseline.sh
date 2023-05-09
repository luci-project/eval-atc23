#!/bin/bash

TESTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TESTBIN="/builds/test/run"
DOCKERFLAGS=( "--add-host=host.docker.internal:host-gateway" )
PACKAGES=( )
TESTLOG=""
DELAY=40
PID=0

function testlog() {
	if [[ -n "${TESTLOG:-}" ]] ; then
		if [[ -f /.dockerenv ]]; then
			logfile="${TESTLOG}/out-docker-test.log"
		else 
			logfile="${TESTLOG}/out-test.log"
		fi
	else
		logfile="/dev/null"
	fi
	sed -e "s/^/[$(date -Iseconds)] /" | tee -a "${logfile}"
}

# Called before starting the docker container
# Parameter 1: path to base directory
# Parameter 2: path to log directory
# Parameter 3...: The target directory names containing the different library versions
function preload() {
	base=$1
	shift
	TESTLOG="$1"
	shift

	echo "Testing baseline $@"

	sleep 1
}

# Called in docker at start
# Parameter 1: path to ld-luci.so
# Parameter 2: path to log directory
function prepare() {
	TESTLOG="$2"
	mkdir -p "$(dirname "$TESTBIN")"
	cp "./test/runtests" "$TESTBIN"
}

function restart() {
	if [[ $PID -ne 0 ]] ; then
		if kill $PID ; then
			echo "Killed test app with PID $PID" | testlog
		else
			echo "Test app with PID $PID seems to be crashed!" | testlog
		fi
	fi

	# let it settle
	sleep 3

	SUFFIX=$(date +%Y-%m-%d_%H-%M-%S)
	TESTCASES=( $(find /builds/target/test/ -name "*.so") )
	$TESTBIN -1 ${TESTCASES[@]} >/dev/null 2> "${TESTLOG:-/tmp}/run-$SUFFIX.err" &
	PID=$!
	echo "Started test app with PID $PID" | testlog
}

# Called in docker after linking a (new) library version
# Parameter 1: path to directory with current library version
# Parameter 2: path to log directory
function run() {
	sleep 20
	restart
}

# Called in docker after all versions have been tested
# Parameter 1: path to base directory
# Parameter 2: path to log directory
function stop() {
	kill $PID
	echo "Finished docker" | testlog
}

# Called after the docker container exited
# Parameter 1: path to base directory
# Parameter 2: path to log directory
function cleanup() {
	echo "Creating summary" | testlog
	echo "**libxcrypt Vanilla Baseline**" > $2/run-summary.txt
	$1/summary-runs.py $2 >> $2/run-summary.txt | testlog
	echo "Logs are stored in $2"
}

source "${TESTDIR}/../tools/testor.sh"

#!/bin/bash

TESTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
TESTBIN="/builds/test/run"
DOCKERFLAGS=( "--add-host=host.docker.internal:host-gateway" )
PACKAGES=( )
TESTLOG=""
DELAY=10
PID=0
ELFVARSD=0
ELFVARSPORT=9001

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

	echo "Testing $@"

	if [[ -z ${NODEBUG+exist} ]] ; then
		echo "Preparing elfvars service by precalculating hashes" | testlog
		bean-elfvarsd -c '.test-cache' CACHE $@
		
		echo "Starting elfvars service to provide hashes" | testlog
		bean-elfvarsd -c '.test-cache' 0.0.0.0:$ELFVARSPORT $@ >"$TESTLOG/elfvarsd.log" 2>"$TESTLOG/elfvarsd.err" &
		ELFVARSD=$!
		sleep 1
	fi
}

# Called in docker at start
# Parameter 1: path to ld-luci.so
# Parameter 2: path to log directory
function prepare() {
	TESTLOG="$2"
	echo "Test environment (docker) started" | testlog
	# save version info
	/opt/luci/ld-luci.so -V > "$2/luci.build"

	# Prepare test binary
	mkdir -p "$(dirname "$TESTBIN")"
	cp "./test/runtests" "$TESTBIN"
	elfo-setinterp "$TESTBIN" "$1"

	# Set up luci configuration
	export LD_LOGLEVEL=6
	export LD_LOGFILE="$2/luci.log"
	export LD_LOGFILE_APPEND=1
	export LD_STATUS_INFO="$2/status.info"
	export LD_EARLY_STATUS_INFO=1
	export STATUS_LOG="$2/status.log"
	if [[ -z ${NODEBUG+exist} ]] ; then
		export LD_DEBUG_HASH="tcp:$(getent hosts host.docker.internal | cut -d' ' -f1):$ELFVARSPORT"
	fi
	export LD_DYNAMIC_UPDATE=1
	export LD_DYNAMIC_DLUPDATE=1
	export LD_RELOCATE_OUTDATED=0
	export LD_DETECT_OUTDATED=1
	export LD_DEPENDENCY_CHECK=1
}

function restart() {
	if [[ $PID -ne 0 ]] ; then
		if kill $PID ; then
			echo "Killed test app with PID $PID" | testlog
		else
			echo "Test app with PID $PID seems to be crashed!" | testlog
		fi
	fi
	if [ -f "$LD_STATUS_INFO" ] ; then
		cat "$LD_STATUS_INFO" >> "$STATUS_LOG"
	fi
	SUFFIX=$(date +%Y-%m-%d_%H-%M-%S)
	$TESTBIN > "${TESTLOG:-/tmp}/run-$SUFFIX.log" 2> "${TESTLOG:-/tmp}/run-$SUFFIX.err" &
	PID=$!
	echo "Started test app with PID $PID" | testlog
}

# Called in docker after linking a (new) library version
# Parameter 1: path to directory with current library version
# Parameter 2: path to log directory
function run() {
	sleep 5
	if [[ $PID -eq 0 ]] ; then
		restart
	elif ! kill -0 $PID > /dev/null ; then
		restart
	elif [ -f "$LD_STATUS_INFO" ] && egrep "^(FAILED|ERROR) .* libz.so" "$LD_STATUS_INFO" ; then
		echo "Luci status has failed update:" | testlog
		sed -e "s/^/    /" "$LD_STATUS_INFO" | testlog
		cat "$LD_STATUS_INFO" >> "$STATUS_LOG"
		echo > "$LD_STATUS_INFO"
		restart
	fi
}

# Called in docker after all versions have been tested
# Parameter 1: path to base directory
# Parameter 2: path to log directory
function stop() {
	kill $PID
	if [ -f "$LD_STATUS_INFO" ] ; then
		echo "Remaining luci status:" | testlog
		sed -e "s/^/    /" "$LD_STATUS_INFO" | grep " libz.so" | testlog
	fi
	if [ -f "$LD_STATUS_INFO" ] ; then
		cat "$LD_STATUS_INFO" >> "$STATUS_LOG"
	fi
	echo "Finished docker" | testlog
}

# Called after the docker container exited
# Parameter 1: path to base directory
# Parameter 2: path to log directory
function cleanup() {
	if [[ -z ${NODEBUG+exist} ]] ; then
		echo "Stopping elfvars service" | testlog
		kill $ELFVARSD
	fi
	echo "**Zlib dynamic updates with Luci**" > $2/run-summary.txt
	if grep "/backtesting/" $2/link.log >/dev/null 2>&1 ; then
		# Version output of zlib is not sufficient for backtesting - we need to translate it to the package number
		$1/summary-runs.py -t $2 >> $2/run-summary.txt | testlog
	else
		$1/summary-runs.py $2 >> $2/run-summary.txt | testlog
	fi
	echo "Logs are stored in $2"
}

source "${TESTDIR}/../tools/testor.sh"

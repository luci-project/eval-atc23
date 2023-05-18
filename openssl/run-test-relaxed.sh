#!/bin/bash

TESTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
SSLDIR="/tmp/ssl"
SSLBIN="$SSLDIR/openssl"
DOCKERFLAGS=( "--add-host=host.docker.internal:host-gateway" )
PACKAGES=( )
TESTLOG=""
DELAY=10
PID=0
ELFVARSD=0
ELFVARSPORT=9001


# local function for logging
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

	# start DWARF hashing service (on host)
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

	# generate cert
	mkdir -p "$SSLDIR"
	OPENSSLBIN=$3/bin/openssl
	if [[ -x "$OPENSSLBIN" ]] ; then
		mkdir -p /usr/lib/ssl/
		cp $3/openssl.cnf /usr/lib/ssl/
	else
		apt install -y openssl
		OPENSSLBIN=/usr/bin/openssl
	fi
	cp $OPENSSLBIN "$SSLBIN"
	elfo-setinterp "$SSLBIN" "$1"

	$OPENSSLBIN req -x509 -newkey rsa:2048 -keyout $SSLDIR/key.pem -out $SSLDIR/cert.pem -days 365 -nodes -subj "/C=DE/ST=Erlangen/L=Erlangen/O=FAU/OU=i4/CN=sys.cs.fau.de"

	# Permanently try s_time
	while true ; do
		date
		$OPENSSLBIN s_time -time 1 || true
		sleep 1
	done >"$2/client.log" 2>"$2/client.err" &
	export CLIENT_PID=$!

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
	export LD_SKIP_IDENTICAL=1
	export LD_DYNAMIC_UPDATE=1
	export LD_DYNAMIC_DLUPDATE=1
	export LD_RELOCATE_OUTDATED=1
	export LD_DETECT_OUTDATED=userfaultfd
	export LD_DETECT_OUTDATED_DELAY=3
	export LD_DEPENDENCY_CHECK=1
	export LD_RELAX_CHECK=1
}

# local function restarting the test application
function restart() {
	# Check status of app
	if [[ $PID -ne 0 ]] ; then
		if kill $PID ; then
			echo "Killed test app with PID $PID" | testlog
		else
			echo "Test app with PID $PID seems to be crashed!" | testlog
		fi
	fi

	# Append status info to permanent log
	if [ -f "$LD_STATUS_INFO" ] ; then
		cat "$LD_STATUS_INFO" >> "$STATUS_LOG"
	fi

	# Wait a few seconds (makes log data more clear)
	sleep 2

	# (Re)start app
	SUFFIX=$(date +%Y-%m-%d_%H-%M-%S)
	$SSLBIN s_server -key $SSLDIR/key.pem -cert $SSLDIR/cert.pem -unlink -rev > "${TESTLOG:-/tmp}/run-${SUFFIX}-server.log" 2> "${TESTLOG:-/tmp}/run-${SUFFIX}-server.err" &
	PID=$!
	echo "Started test app with PID $PID" | testlog
}

# Called in docker after linking a (new) library version
# Parameter 1: path to directory with current library version
# Parameter 2: path to log directory
function run() {
	sleep 10
	if [[ $PID -eq 0 ]] ; then
		restart
	elif ! kill -0 $PID > /dev/null ; then
		restart
	elif [ -f "$LD_STATUS_INFO" ] && egrep "^(FAILED|ERROR) .* lib(ssl|crypto)\.so" "$LD_STATUS_INFO" ; then
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
	kill $CLIENT_PID
	kill $PID
	if [ -f "$LD_STATUS_INFO" ] ; then
		echo "Remaining luci status:" | testlog
		sed -e "s/^/    /" "$LD_STATUS_INFO" | egrep " lib(ssl|crypto)\.so" | testlog
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
	echo "Logs are stored in $2"
}

source "${TESTDIR}/../tools/testor.sh"

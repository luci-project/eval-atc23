#!/bin/bash

TESTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ $# -ne 3 ]] ; then
	echo "Usage: $0 [TYPE] [FROM] [TO]" >&2
	echo
	echo "e.g. $0 relaxed 1.1.1 1.1.1f" >&2

	exit 1
fi

SCRIPT="${TESTDIR}/run-test-$1.sh"
if [ ! -x "$SCRIPT" ] ; then
	echo "Script '$SCRIPT' does not exist or is not executable" >&2
	exit 1
else
	export LOGPREFIX="log-vanilla-$1"
fi

if [[ $2 =~ ([0-9]+)[._]([0-9]+)[._]([0-9]+[a-z]*)$ ]]; then
	if [[ ${BASH_REMATCH[1]} -lt 3 ]] ; then
		start="OpenSSL_${BASH_REMATCH[1]}_${BASH_REMATCH[2]}_${BASH_REMATCH[3]}"
	else
		start="openssl-${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
	fi
	if [[ ! -L "${TESTDIR}/release/all/$start" ]] ; then
		echo "From-Parameter '$2' is not a valid release" >&2
		exit 1
	fi
else
	echo "From-Parameter '$2' has not a valid release format" >&2
	exit 1
fi

if [[ $3 =~ ([0-9]+)[._]([0-9]+)[._]([0-9]+[a-z]*)$ ]]; then
	if [[ ${BASH_REMATCH[1]} -lt 3 ]] ; then
		end="OpenSSL_${BASH_REMATCH[1]}_${BASH_REMATCH[2]}_${BASH_REMATCH[3]}"
	else
		end="openssl-${BASH_REMATCH[1]}.${BASH_REMATCH[2]}.${BASH_REMATCH[3]}"
	fi
	if [[ ! -L "${TESTDIR}/release/all/$end" ]] ; then
		echo "From-Parameter '$3' is not a valid release" >&2
		exit 1
	fi
else
	echo "To-Parameter '$3' has not a valid release format" >&2
	exit 1
fi

releases=( $(cd "${TESTDIR}" ; find release/all -type l | sort -V | sed -n "/\/$start\$/,\$p" | sed "/\/$end\$/q") )
if [[ ${#releases[@]} -le 1 ]] ; then
	echo "Not enough versions in range from $start to $end to do serious testing" >&2
else
	echo "$1 ${#releases[@]} vanilla versions from $( basename ${releases[0]} ) to $( basename ${releases[-1]} )"
	"${SCRIPT}"  ${releases[@]}
fi

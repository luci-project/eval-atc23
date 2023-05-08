#!/bin/bash

TESTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ $# -ne 3 ]] ; then
	echo "Usage: $0 [TYPE] [FROM] [TO]" >&2
	echo
	echo "e.g. $0 test 2.2.0 2.5.0" >&2

	exit 1
fi

SCRIPT="${TESTDIR}/run-$1.sh"
if [ ! -x "$SCRIPT" ] ; then
	echo "Script '$SCRIPT' does not exist or is not executable" >&2
	exit 1
else
	export LOGPREFIX="log-vanilla-$1"
fi

if [[ $2 =~ ([0-9]+)[._]([0-9]+)[._]([0-9]+)$ ]]; then
	start="R_${BASH_REMATCH[1]}_${BASH_REMATCH[2]}_${BASH_REMATCH[3]}"
	if [[ ! -L release/$start ]] ; then
		echo "From-Parameter '$2' is not a valid release" >&2
		exit 1
	fi
else
	echo "From-Parameter '$2' has not a valid release format" >&2
	exit 1
fi

if [[ $3 =~ ([0-9]+)[._]([0-9]+)[._]([0-9]+)$ ]]; then
	end="R_${BASH_REMATCH[1]}_${BASH_REMATCH[2]}_${BASH_REMATCH[3]}"
	if [[ ! -L release/$end ]] ; then
		echo "From-Parameter '$3' is not a valid release" >&2
		exit 1
	fi
else
	echo "To-Parameter '$3' has not a valid release format" >&2
	exit 1
fi

releases=( $(cd "${TESTDIR}" ; find release -type l | sort -V | sed -n "/\/$start\$/,\$p" | sed "/\/$end\$/q") )
if [[ ${#releases[@]} -le 1 ]] ; then
	echo "Not enough versions in range from $start to $end to do serious testing" >&2
else
	echo "$1 ${#releases[@]} vanilla versions from $( basename ${releases[0]} ) to $( basename ${releases[-1]} )"
	"${SCRIPT}"  ${releases[@]}
fi

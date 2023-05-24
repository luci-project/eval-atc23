#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ $# -ne 4 ]] ; then
	echo "Usage: $0 [DISTRIBUTION] [VERSION] [TYPE] [PACKAGE]" >&2
	echo
	echo "e.g. $0 debian buster libcrypt1" >&2

	exit 1
fi

SCRIPT="${DIR}/run-test-$3.sh"
if [ ! -x "$SCRIPT" ] ; then
	echo "Script '$SCRIPT' does not exist or is not executable" >&2
	exit 1
fi

TESTDIR="${DIR}/backtesting/$1/$2/$4"
if [[ ! -d "$DIR" ]] ; then
	echo "Directory '${DIR}' not found"
	exit 1
fi

releases=( $("${DIR}/../tools/dir_version.py" "${TESTDIR}") )
if [[ ${#releases[@]} -le 1 ]] ; then
	echo "Not enough versions in $1 $2 to do serious testing" >&2
else
	echo "Backtesting ${#releases[@]} $1 $2 package versions from $( basename ${releases[0]} ) to $( basename ${releases[-1]} )"
	export LOGPREFIX="log-$1-$2-$3"
	export NODEBUG=1
	"$SCRIPT" ${releases[@]}
fi


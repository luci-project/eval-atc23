#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

if [[ $# -ne 3 ]] ; then
	echo "Usage: $0 [DISTRIBUTION] [VERSION] [PACKAGE]" >&2
	echo
	echo "e.g. $0 debian buster zlib1g" >&2

	exit 1
fi

TESTDIR="${DIR}/backtesting/$1/$2/$3"
if [[ ! -d "$DIR" ]] ; then
	echo "Directory '${DIR}' not found"
	exit 1
fi

releases=( "${TESTDIR}"/*/ )
if [[ ${#releases[@]} -le 1 ]] ; then
	echo "Not enough versions in $1 $2 to do serious testing" >&2
else
	echo "Backtesting ${#releases[@]} $1 $2 package versions from $( basename ${releases[0]} ) to $( basename ${releases[-1]} )"
	export LOGPREFIX="log-$1-$2"
	export NODEBUG=1
	"${DIR}/run-test.sh" ${releases[@]}
fi


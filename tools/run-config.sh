#!/bin/bash

function title() {
	spaces="                                                             "
	echo -e "\e]2;[Luci ${EVALNAME:-Eval}] $1\a\n\e[1;7m  ${spaces:0:${#1}}  \n  $1  \n  ${spaces:0:${#1}}  \n\e[0m"
}


if [[ -z ${LOGDATE+exist} ]] ; then
	export LOGDATE=$(date +%Y-%m-%d_%H-%M)
fi


if [[ ! -x "${DIR}/../luci/ld-luci-debian-bullseye-x64.so" ]] ; then
	title "Building Luci"
	../setup.sh
fi

RESULTDIR="${DIR}/result-${LOGDATE}"
mkdir "${RESULTDIR}"


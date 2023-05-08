#!/bin/bash
set -euf -o pipefail

SOURCEDIR="/builds/source/"
TARGETDIR="/builds/target/"
TOOLSDIR="/builds/tools/"

BUILDLOG="${TARGETDIR}/${LOGPREFIX:-build}-$(date +%Y-%m-%d_%H-%M).log"

if [[ -z ${SKIPEXISTING+exist} ]] ; then
	SKIPEXISTING=true
fi
if [[ $(type -t build) != function ]] ; then
	echo "build() function missing" >&2
	exit 1
elif [[ $(type -t setup) != function ]] ; then
	echo "setup() function missing" >&2
	exit 1
elif [[ $# -eq 0 ]] ; then
	echo "No commits/range given" >&2
	exit 1
elif [ -f "/.dockerenv" ] ; then
	# Preinit APT
	ln -fs /usr/share/zoneinfo/Europe/Berlin /etc/localtime
	export DEBIAN_FRONTEND=noninteractive
	apt-get update

	# Setup
	setup "${SOURCEDIR}"
	if [[ ! -d "${SOURCEDIR}/.git" ]] ; then
		echo "'${SOURCEDIR}' is not a Git repo" >&2
		exit 1
	fi

	# Get commits
	commits=()
	cd "${SOURCEDIR}"
	for v in $@ ; do
		if [[ "$v" =~ ^\s*([^. ]+)\s*\.\.+\s*([^. ]+)\s*$ ]] ; then
			if ! s=$(git rev-list -n 1 ${BASH_REMATCH[1]}) ; then
				echo "There is no commit for '${BASH_REMATCH[1]}' (start of range)" >&2
				exit 1
			elif ! e=$(git rev-list -n 1 ${BASH_REMATCH[2]}) ; then
				echo "There is no commit for '${BASH_REMATCH[2]}' (end of range)" >&2
				exit 1
			else
				commits+=( $(git rev-list --ancestry-path ${s}..${e}) )
			fi
		elif c=$(git rev-list -n 1 $v) ; then
			commits+=( $c )
		else
			echo "There is no commit for '$c'" >&2
			exit 1
		fi
	done
	echo "${#commits[@]} builds..."

	# Build each commit
	n=0
	for H in ${commits[@]} ; do
		cd "${SOURCEDIR}"
		n=$(( n + 1 ))

		# Prepare
		git show -s --format="$n. Building %h [%cs: %s]" $H
		BUILDDIR="${TARGETDIR}/$H${SUFFIX:-}"
		if [[ -d "${BUILDDIR}" && "$SKIPEXISTING" = true ]] ; then
			echo "Build for $H already exists - skipping" >&2
		else
			# Checkout
			ct=$(git show -s --format="%ct" $H)
			cs=$(git show -s --format="%cs" $H)
			git checkout $H

			# Build
			mkdir -p "${BUILDDIR}"
			if build "${SOURCEDIR}" "${BUILDDIR}" "${TARGETOWNER}" ; then
				git show -s --format="%H %ct %s" $H >> "${BUILDLOG}"
				if [[ -n ${TARGETOWNER+exist} ]] ; then
					chown -R "${TARGETOWNER}" "${BUILDDIR}" || true
				fi
			else
				echo "Building $H failed!" >&2
				rm -rf "${BUILDDIR}"
			fi
			cd "${SOURCEDIR}"

			# Cleanup
			git reset --hard
			git clean -fxd
		fi
		echo
	done
	if [[ -n ${TARGETOWNER+exist} ]] ; then
		chown -R "${TARGETOWNER}" "${BUILDLOG}" || true
	fi
	echo "Done!"
elif [[ $# -ne 0 ]] ; then
	if [[ -z ${BASEDIR+exist} ]] ; then
		if [[ ${#BASH_SOURCE[@]} -gt 1 ]] ; then
			BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[1]}" )" &> /dev/null && pwd )"
			echo "(setting BASEDIR variable to '$BASEDIR'...)" >&2
		else
			echo "BASEDIR variable not set" >&2
			exit 1
		fi
	fi
	if [[ ! -d "${BASEDIR}" ]] ; then
		echo "BASEDIR variable invalid" >&2
		exit 1
	fi

	if [[ -z ${DOCKERFLAGS+exist} ]]; then
		DOCKERFLAGS=()
	fi
	DOCKERFLAGS+=( "--rm" )
	DOCKERFLAGS+=( "-h builder" )
	DOCKERFLAGS+=( "-v" "${BASEDIR}:${TARGETDIR}" )
	DOCKERFLAGS+=( "-v" "$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd ):${TOOLSDIR}:ro" )
	DOCKERFLAGS+=( "-e" "TARGETOWNER=$(id -u):$(id -g)" )
	DOCKERFLAGS+=( "${IMAGE:-debian:bullseye}" )
	DOCKERFLAGS+=( "${TARGETDIR}/$(basename -- "$0")" "$@" )
	if [[ ${DOCKERROOT:-0} -ne 0 ]] ; then
		echo "Running docker as root" >&2
		echo "${DOCKERFLAGS[@]}"
		sudo docker run "${DOCKERFLAGS[@]}"
	else
		docker run "${DOCKERFLAGS[@]}"
	fi
else
	echo "Usage: $0 [Git ref[s]]"
	exit 1
fi

#!/bin/bash
set -euf -o pipefail

BASEURL="https://launchpad.net"
DIST="ubuntu"
VERSION="focal"
ARCH="amd64"
EXTRACT=false
DBGSYM=false
SOURCE=false
PATCH=false
FORCE=false
declare -a PACKAGES

while getopts "A:D:V:d:sSfpxh" arg; do
	case $arg in
		h)
			echo "Fetch (and extract) all package builds from launchpad"
			echo
			echo "Usage: $0 [-A arch] [-D dist] [-V version] [-d dir] [-s] [-S] [-p] [-x] [-h] package[s]"
			echo
			echo "   -A arch     Set architecture (default: ${ARCH})"
			echo "   -D dist     Set distribution (default: ${DIST})"
			echo "   -V version  Set distribution version (default: ${VERSION})"
			echo "   -d dir      Set target directory (for all packages)"
			echo "               instead of creating individual ones for each package"
			echo "   -s          Try to retrieve debug symbols as well"
			echo "               (by appending '-dbg' and '-dbgsym' to package)"
			echo "   -S          Try to retrieve source files"
			echo "   -f          Force downloading of files (overwrite if necessary)"
			echo "   -p          Try to retrieve patch files"
			echo "   -x          Extract packages (in corresponding subdirectories)"
			echo "   -h          Show this help"
			exit 0
			;;
		A)
			ARCH=${OPTARG,,}
			;;
		D)
			DIST=${OPTARG,,}
			;;
		V)
			VERSION=${OPTARG,,}
			;;
		d)
			TARGETDIR=$OPTARG
			;;
		s)
			DBGSYM=true
			;;
		S)
			SOURCE=true
			;;
		f)
			FORCE=true
			;;
		p)
			PATCH=true
			;;
		x)
			EXTRACT=true
			;;
		*)
			echo "Invalid argument '${arg}'"
			exit 1
			;;
	esac
done

shift $((OPTIND-1))
if [ $# -eq 9 ] ; then
	echo "Missing package name"
	exit 1
else
	for ARG in "$@" ; do
		PACKAGES+=( "${ARG}" )
		if [ "$DBGSYM" = true ] ; then
			PACKAGES+=( "${ARG}-dbg" "${ARG}-dbgsym" )
		fi
	done
fi

function urldecode() {
	: "${*//+/ }"
	echo -e "${_//%/\\x}"
}

function download() {
	url="$1"
	file="$(urldecode ${url##*\/})"
	dir="$2"
	build="$3"
	if [ "${FORCE}" = true -o ! -f "${dir}/${file}" ] ; then
		echo " - fetching ${file}"
		mkdir -p "${dir}"
		wget -q -N -P "${dir}" "${url}"
	fi
	if [ "${EXTRACT}" = true ] ; then
		echo " - extracting ${file}"
		mkdir -p "${dir}/${build}"
		case $file in
			*\.tar\.gz | *\.tar\.xz | *\.tar\.bz2)
				mkdir -p "${dir}/.source/${file%%.tar.*}"
				tar -xf "${dir}/${file}" -C "${dir}/.source/${file%%.tar.*}/"
				if [ ! -L "${dir}/${build}/${file%%.tar.*}" ] ; then
					ln -r -s "${dir}/.source/${file%%.tar.*}" "${dir}/${build}/${file%%.tar.*}"
				fi
				;;
			*\.gz)
				zcat "${dir}/${file}" > "${dir}/${build}/${file%%.gz}"
				;;
			*\.deb | *\.ddeb)
				dpkg-deb -x "${dir}/${file##*\/}" "${dir}/${build##*\/}"
				;;
			*)
				if [ ! -L "${dir}/${build}/${file}" ] ; then
					ln -r -s "${dir}/${file}" "${dir}/${build}/${file}"
				fi
				;;
		esac
	fi
}


TMP_OVERVIEW=$(mktemp)
TMP_SOURCE=$(mktemp)
for PACKAGE in ${PACKAGES[@]} ; do
	if [ -z ${TARGETDIR+empty} ] ; then
		DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )/${DIST}-${VERSION}/${PACKAGE%%-dbg*}"
	else
		DIR="${TARGETDIR}"
	fi

	echo -e "\e[1mSearching for all builds of '${PACKAGE}' in ${DIST} ${VERSION}\e[0m"
	if wget -q "-O${TMP_OVERVIEW}" "${BASEURL}/${DIST}/${VERSION}/${ARCH}/${PACKAGE}" ; then
		sed -ne "s|^.*<a href=\"\(/${DIST}/${VERSION}/${ARCH}/${PACKAGE}/.*\)\">.*</a>.*$|\1|p" "${TMP_OVERVIEW}" | sort -u | while read build ; do
			echo "Checking ${build}..."

			TMP_SITE=$(mktemp)
			if wget -q "-O${TMP_SITE}" "${BASEURL}${build}" ; then
				sed -ne "s|^.*<a class=\"sprite\" href=\"\(.*\.[d]\+eb\)\">.*</a>.*$|\1|p" "${TMP_SITE}" | sort -u | while read file ; do
					download "${file}" "${DIR}" "${build##*\/}"
				done

				if [ "${SOURCE}" = true -o "${PATCH}" = true ] ; then
					sed -ne "s|^.*<a href=\"\(/${DIST}/+source/.*\)\">.*</a>.*$|\1|p" "${TMP_SITE}" | grep -v "/+build/" | sort -u | while read source ; do
						echo " - checking source at ${source}"

						TMP_SOURCE=$(mktemp)
						if wget -q "-O${TMP_SOURCE}" "${BASEURL}${source}" ; then

							if [ "${SOURCE}" = true ] ; then
								sed -ne "s|^.*<a class=\"sprite download\" href=\"\(.*\)\">.*</a>.*$|\1|p" "${TMP_SOURCE}" | sort -u | while read file ; do
									download "$file" "${DIR}" "${build##*\/}"
								done
							fi

							if [ "${PATCH}" = true ] ; then
								sed -ne "s|^.*<a href=\"\(.*\.diff\.gz\)\">.*</a>.*$|\1|p" "${TMP_SOURCE}" | sort -u | while read file ; do
									download "$file" "${DIR}" "${build##*\/}"
								done
							fi
						fi
						rm -f "${TMP_SOURCE}"
					done
				fi
			fi
			rm -f "${TMP_SITE}"
		done
	else
		echo " (not found)"
	fi
done
rm -f "${TMP_SOURCE}"

rm "${TMP_OVERVIEW}"

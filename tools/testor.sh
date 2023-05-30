#!/bin/bash
set -euf -o pipefail

TARGETDIR="/builds/target/"
TOOLSDIR="/builds/tools/"
TMPROOTDIR="/builds/tmproot/"
LUCISOURCE="/builds/luci/"
LUCITARGET="/opt/luci/"
SCRIPTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

function logmsg() {
	echo "[$(date -Iseconds)] $@" | tee -a "${LOGDIR}/link.log"
}

function linktarget() {
	cd "$1"
	logmsg "Linking $1"
	# Create directory structure
	find . -type d -exec mkdir -p "${TMPROOTDIR}/{}" ';'
	# Create symlinks for all files
	find . -type 'f,l' -exec ln -sf "$1/{}" "${TMPROOTDIR}/{}" ';'
	if [[ "${KEEPLINKS:-0}" -eq 0 ]] ; then
		# Delete old symlinks (pointing to other builds)
		find "${TMPROOTDIR}" -type l ! -lname "$1/*" -exec rm "{}" ';'
	fi
}

if [[ -z ${DELAY+exist} ]] ; then
	DELAY="1m"
fi
if [[ $(type -t run) != function ]] ; then
	echo "run() function missing" >&2
	exit 1
elif [ -f "/.dockerenv" ] ; then
	# Preinit APT
	ln -fs /usr/share/zoneinfo/UTC /etc/localtime
	export DEBIAN_FRONTEND=noninteractive
	# Use alternative debian repo
	echo "Acquire { https::Verify-Peer false }" >/etc/apt/apt.conf.d/99verify-peer.conf
	sed -ie "s|http://deb.debian.org/|https://debian.inf.tu-dresden.de/|" /etc/apt/sources.list
	apt-get update
	apt install -y make ${PACKAGES[@]:-}

	# Log directory
	mkdir -p "${LOGDIR}"
	logmsg "Installing luci"

	# Install Luci
	mkdir -p "${LUCITARGET}"
	make -C "${LUCISOURCE}" install-only
	export PATH="$PATH:/opt/luci/:$LUCISOURCE/bean/:$LUCISOURCE/bean/elfo/"
	# Prepare Lib directory
	sed -i "1s|^|${TMPROOTDIR}lib/\n${TMPROOTDIR}lib64/\n|" "${LUCITARGET}libpath.conf"
	if [[ "${NOLIBPATH:-0}" -eq 0 ]] ; then
		export LD_LIBRARY_PATH="${TMPROOTDIR}lib;${TMPROOTDIR}lib/x86_64-linux-gnu;${TMPROOTDIR}lib64;${TMPROOTDIR}usr/lib;${TMPROOTDIR}usr/lib/x86_64-linux-gnu"
	fi

	# Prepare testutil
	cd "${TARGETDIR}"
	if [[ $(type -t prepare) == function ]] ; then
		logmsg "Preparing luci"
		prepare "${LUCITARGET}ld-luci.so" "${LOGDIR}" "$@"
	fi

	# For each version.link libs and run/check test
	mkdir -p "${TMPROOTDIR}"
	for dir in "$@" ; do
		echo "Linking $dir" >&2
		linktarget "${TARGETDIR}${dir}"
		cd "${TARGETDIR}"
		run "${TARGETDIR}$dir" "${LOGDIR}"
		echo "Sleeping $DELAY" >&2
		sleep "$DELAY"
	done

	if [[ $(type -t stop) == function ]] ; then
		stop "${TARGETDIR}" "${LOGDIR}"
	fi

	if [[ -n ${TARGETOWNER+exist} ]] ; then
		logmsg "Setting permissions for ${TARGETOWNER}"
		chown -R "${TARGETOWNER}" "${LOGDIR}" || true
	fi
	logmsg "Finished"
	exit 0
else
	in=()
	if [[ $# -ne 0 ]] ; then
		in+=($@)
	elif [[ ! -t 0 ]] ; then
		echo "Reading hashes from build file..."
		in+=( $(cut -d' ' -f1 ) )
	else
		echo "Usage:"
		echo "	$0 [directories]"
		echo "or"
		echo "	$0 < build.log"
		exit 1
	fi

	args=()
	if [[ -z ${TESTDIR+exist} ]] ; then
		if [[ ${#BASH_SOURCE[@]} -gt 0 ]] ; then
			TESTDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
			echo "(setting TESTDIR variable to '$TESTDIR'...)" >&2
		else
			echo "TESTDIR variable not set" >&2
			exit 1
		fi
	else
		TESTDIR=$(readlink -f "$TESTDIR")
		if [[ ! -d "$TESTDIR" ]] ; then
			echo "Test directory '$TESTDIR' in config is invalid" >&2
			exit 1
		fi
	fi
	for i in "${in[@]}" ; do
		iabs=$(readlink -f "$i")
		if [[ ! -d "$iabs" ]] ; then
			echo "Parameter '$i' ('$iabs') is not a valid directory (ignoring)"  >&2
		elif [[ "$iabs" != "$TESTDIR/"* ]] ; then
			echo "Parameter '$i' ('$iabs') is not a subdirectory of '$TESTDIR'"  >&2
			exit 1
		else
			args+=( ${iabs#"$TESTDIR/"} )
		fi
	done

	if [[ -z ${LUCIDIR+exist} ]] ; then
		LUCIDIR="$(readlink -f "${SCRIPTDIR}/../luci")"
		echo "(setting LUCIDIR variable to '$LUCIDIR'...)" >&2
	fi

	if [[ -z ${DOCKERFLAGS+exist} ]] ; then
		DOCKERFLAGS=()
	fi

	if [[ ! -d "${LUCIDIR}" ]] ; then
		echo "LUCIDIR variable invalid" >&2
		exit 1
	elif [[ ! -d "${TESTDIR}" ]] ; then
		echo "TESTDIR variable invalid" >&2
		exit 1
	elif [[ ${#args[@]} -eq 0 ]] ; then
		echo "No valid directories given" >&2
		exit 1
	else
		LOGDIR="${LOGPREFIX:-log}-${LOGDATE:-$(date +%Y-%m-%d_%H-%M)}"
		mkdir -p "${TESTDIR}/${LOGDIR}"

		if [[ $(type -t preload) == function ]] ; then
			preload "${TESTDIR}" "${TESTDIR}/${LOGDIR}" "${args[@]}"
		fi
		if [[ $(type -t cleanup) == function ]] ; then
			trap "cleanup ${TESTDIR} ${TESTDIR}/${LOGDIR}" EXIT
		fi

		if [[ -z ${DOCKERFLAGS+exist} ]]; then
			DOCKERFLAGS=()
		fi
		DOCKERFLAGS+=( "--rm" )
		DOCKERFLAGS+=( "-h tester" )
		DOCKERFLAGS+=( "--cap-add" "SYS_PTRACE")
		DOCKERFLAGS+=( "--security-opt" "seccomp=unconfined" )
		DOCKERFLAGS+=( "--security-opt" "apparmor=unconfined" )
		if [[ ${DOCKERROOT:-0} -ne 0 ]] ; then
			DOCKERFLAGS+=( "--privileged")
			DOCKERFLAGS+=( "--cap-add" "SYS_ADMIN")
			DOCKERFLAGS+=( "-v" "/sys/kernel/debug:/sys/kernel/debug")
		fi
		DOCKERFLAGS+=( "-v" "${TESTDIR}:${TARGETDIR}" )
		DOCKERFLAGS+=( "-v" "${SCRIPTDIR}:${TOOLSDIR}:ro" )
		DOCKERFLAGS+=( "-v" "${LUCIDIR}:${LUCISOURCE}:ro" )
		DOCKERFLAGS+=( "-e" "LOGDIR=${TARGETDIR}/${LOGDIR}" )
		DOCKERFLAGS+=( "-e" "TARGETOWNER=$(id -u):$(id -g)" )
		if [[ -n ${NODEBUG+exist} ]] ; then
			DOCKERFLAGS+=( "-e" "NODEBUG=${NODEBUG}" )
		fi
		DOCKERFLAGS+=( "${IMAGE:-debian:bullseye}" )
		DOCKERFLAGS+=( "${TARGETDIR}/$(basename -- "$0")" "${args[@]}" )
		if [[ ${DOCKERROOT:-0} -ne 0 ]] ; then
			echo "Running docker as root" >&2
			echo "${DOCKERFLAGS[@]}"
			sudo docker run "${DOCKERFLAGS[@]}" 2>&1 | tee "${LOGDIR}/out-docker.log"
		else
			docker run "${DOCKERFLAGS[@]}" 2>&1 | tee "${LOGDIR}/out-docker.log"
		fi
	fi
fi

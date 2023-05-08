#!/bin/bash

if [[ $# -eq 0 ]] ; then
	echo "Usage: $0 [LOGDIR]" >&2
	exit 1
fi
for DIR in $@ ; do
	if [[ ! -d "$DIR" ]] ; then
		echo "Not a directory: $DIR" >&2
	elif [[ ! -f "$DIR/link.log" ]] ; then
		echo "Missing $DIR/link.log" >&2
	elif [[ ! -f "$DIR/link.log" ]] ; then
		echo "Missing $DIR/status.log" >&2
	else
		echo "# $DIR"

		LIBS=( $(sed -ne "s|^.*\] Linking /builds/target/||p" "$DIR/link.log") )
		if [[ ${#LIBS[@]} -eq 0 ]] ; then
			echo "Error - nothing linked" >&2
			exit 1
		fi

		IFS='/' read -ra first <<< "${LIBS[0]}"
		if [[ "${first[0],,}" = "backtesting" ]] ; then
			IFS='/' read -ra last <<< "${LIBS[-1]}"
			echo -n "${first[1]^} ${first[2]^} (${first[3]} ${first[4]%%-*} - ${last[4]%%-*}): "
		else
			echo -n "Custom (vanilla): "
		fi

		UPDATABLE=$(( ${#LIBS[@]} - 1))
		if [[ $UPDATABLE -eq 0 ]] ; then
			echo "0"
		else
			SUCCESS=$(egrep "^(SUCCESS \(updated to new version\)|IGNORED \([^\)]+\)) for libexpat.so.1" "$DIR/status.log" | wc -l)
			echo "$SUCCESS / $UPDATABLE ($(( (1000 * SUCCESS / UPDATABLE + 5) / 10))%)"
		fi
	fi
	echo
done

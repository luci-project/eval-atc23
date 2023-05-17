#!/bin/bash

BASEDIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
cd ${BASEDIR}

# Delete vanilla builds
find . -regextype egrep -regex '^./[0-9a-f]{40}$' -type d -exec rm -rf {} \;

# Delete extracted backtesting (but keep the downloaded archives due to ratelimit)
if [[ -d backtesting ]] ; then
	echo "Keeping downloaded backtesting packages -- manually remove directory 'backtesting' if you realy want to delete them"
	rm -rf backtesting/*/*/*/*/
fi

# Delete log files
rm -f build-*.log

# Delete log folders
rm -rf log-* result-*

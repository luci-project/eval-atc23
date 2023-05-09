#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# Fetch latest version
git pull --ff-only origin master

# Run setup (again)
"$DIR/setup.sh"

# Continue with program from parameter (hacky)
if [[ $# -gt 0 ]] ; then
	$@
fi

#!/bin/bash

# Change to script directory
cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

# Fetch latest version
git pull --ff-only origin master

# Run setup (again)
./setup.sh

# Continue with program from parameter (hacky)
if [[ $# -gt 0 ]] ; then
	$@
fi

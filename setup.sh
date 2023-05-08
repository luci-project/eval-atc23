#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

LUCIDIR="/opt/luci"
if [ ! -d "$LUCIDIR" ] ; then
	# create RTLD directory
	sudo mkdir -p /opt/luci
	sudo chown -R $(id -u):$(id -g) /opt/luci
fi

# Load submodules
git submodule update --init --recursive

# build version for current distribution
make -C "${DIR}/luci"
# build versions for all distributions
make -C "${DIR}/luci" all

# Build and install Bean utilities
make -B
if command -v pip3 &>/dev/null ; then echo foo 
	pip3 install -r "${DIR}/luci/bean/requirements.txt"
elif command -v pip &>/dev/null ; then
	pip install -r "${DIR}/luci/bean/requirements.txt"
else
	echo "Python package manager (pip) not found - not installing requirements, Bean tools might not work as expacted!" >&2
fi
make -C "${DIR}/luci/bean" -B all
make -C "${DIR}/luci/bean" install

# Build and install elfo utilities
make -C "${DIR}/luci/bean/elfo" -B all
make -C "${DIR}/luci/bean/elfo" install


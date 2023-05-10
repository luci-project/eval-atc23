#!/bin/bash

export LOGDATE=$(date +%Y-%m-%d_%H-%M)

echo -e "\n\e[1mLuci Experiments\e[0m\n"
echo "Execute all experiments, which will take several (~5) hours."
echo "But the scripts will take care of everything"
echo "and store relevant information in log files"
echo "(folders with a '-${LOGDATE}' suffix)."
echo
echo "During this time no human interaction is needed :)"
if ! mkdir -p /opt/luci ; then
	echo "besides entering your credentials to create '/opt/luci'"
fi

docker_ps=$(docker ps -q)
if [[ -n "${docker_ps}" ]] ; then
	echo -e "\n\e[31mWarning - Docker container running:\e[0m"
	docker ps
	echo
	echo "If a container belongs to a previous Luci experiments,"
	echo "please kill it using 'docker kill <ID>' before continuing!"
fi

echo
echo "     (starting in 10 seconds)"
echo
sleep 10s

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

# Build and install
./setup.sh

# Run example testcase
./luci/test/run.sh -u 2-example

# Expat experiment
SECONDS=0
./expat/run.sh
duration_expat=$SECONDS

# libxcrypt experiment
SECONDS=0
./libxcrypt/run.sh
duration_libxcrypt=$SECONDS

# zlib experiment
SECONDS=0
./zlib/run.sh
duration_zlib=$SECONDS

# summary
echo -e "\n\n\e[1mRuntime for Luci Artifacts\e[0m"
echo "  $(( duration_expat / 60 )) Minutes for Expat"
echo "  $(( duration_libxcrypt / 60 )) Minutes for libxcrypt "
echo "  $(( duration_zlib / 60 )) Minutes for zlib"
echo
echo "Have a look at */result-${LOGDATE} :)"


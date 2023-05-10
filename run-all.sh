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

if ! uname -a | grep x86_64 ; then
	echo -e "\n\e[31mWarning - seems like you are not using a x86_64 architecture!\e[0m"
	echo "Luci will most likely not run..."
fi
if [[ "$(uname)" != "Linux"* ]] ; then
	echo -e "\n\e[31mWarning - seems like you are not using GNU/Linux!\e[0m"
	echo "Luci will probably not run..."
elif [[ -f "/etc/os-release" ]] ; then
	source /etc/os-release
	if [[ "${ID,,}" != "debian" && "${ID_LIKE,,}" != "debian" ]] ; then
		echo -e "\n\e[31mWarning - seems like you are not using a debianoid distribution!\e[0m"
		echo "Experiments might not run as expected..."
	elif [[ "${ID,,}" != "ubuntu" ]] ; then
		echo -e "\n\e[33mWarning - seems like you are not using Ubuntu!\e[0m"
		echo "Might not be able to extract Ubuntu Jammy packages..."
	fi
fi

if [ ! -x "$(command -v docker)" ]; then
	echo -e "\n\e[31mWarning - seems like Docker engine is not installed!\e[0m"
	echo "Experiments will probably not run..."
elif [[ -n "$(docker ps -q)" ]] ; then
	echo -e "\n\e[31mWarning - Docker container running:\e[0m"
	docker ps
	echo
	echo "If a container belongs to a previously started Luci experiments,"
	echo "please kill it using 'docker kill <ID>' before continuing!"
fi

echo
echo "     (starting in 10 seconds)"
echo
sleep 10s

cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null

# Build if required
if [[ ! -x "./luci/ld-luci-debian-bullseye-x64.so" ]] ; then
	./setup.sh
fi

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


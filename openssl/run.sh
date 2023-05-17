#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cd "$DIR"

EVALNAME="OpenSSL"

source ../tools/run-config.sh

## Vanilla

if echo release/* | xargs -n1 test -e ; then
	echo "All libraries seem to exist -- cleanup for rebuild!"
else
	title "Building libraries"
	#./gen-lib.sh OpenSSL_1_0_0{,{a..t}} OpenSSL_1_0_1{,{a..u}} OpenSSL_1_0_2{,{a..u}} OpenSSL_1_1_0{,{a..l}} OpenSSL_1_1_1{,{a..s}} openssl-3.0.{0..7}
	./gen-lib.sh OpenSSL_1_1_0{,{a..l}} OpenSSL_1_1_1{,{a..s}}
fi

title "Generating comparison tables"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -r -d -s release/v1.1.1 -o "${RESULTDIR}/misc-compatibility-vanilla.htm"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -i -r -d -s release/v1.1.1 -o "${RESULTDIR}/misc-compatibility-vanilla-relaxed.htm"

title "Evaluating Vanilla Luci (strict)"
./eval-vanilla.sh strict 1.1.1 1.1.1s
test -d "log-vanilla-strict-${LOGDATE}" && ln -rs "log-vanilla-strict-${LOGDATE}" "${RESULTDIR}/log-vanilla-strict" || true

title "Evaluating Vanilla Luci (relaxed)"
./eval-vanilla.sh relaxed 1.1.1 1.1.1s
test -d "log-vanilla-relaxed-${LOGDATE}" && ln -rs "log-vanilla-relaxed-${LOGDATE}" "${RESULTDIR}/log-vanilla-relaxed" || true


## Backtesting

title "Retrieving packages for Debian Buster"
../tools/snapshot-dates.py -a debian debian-security -s "buster.*" -- zlib1g | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq
../tools/snapshot-fetch.py -d backtesting/debian/buster -x libssl1.1 1.1.1-1 1.1.1-2 1.1.1a-1 1.1.1b-1 1.1.1b-2 1.1.1c-1 1.1.1d-0+deb10u1 1.1.1d-0+deb10u2 1.1.1d-0+deb10u3 1.1.1d-0+deb10u4 1.1.1d-0+deb10u5 1.1.1d-0+deb10u6 1.1.1d-0+deb10u7 1.1.1d-0+deb10u8 1.1.1n-0+deb10u1 1.1.1n-0+deb10u2 1.1.1n-0+deb10u3 1.1.1n-0+deb10u4
title "Generating comparison tables for Debian Buster"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -r -d -N backtesting/debian/buster/libssl1.1 -o "${RESULTDIR}/misc-debian-buster.htm"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -i -r -d -N backtesting/debian/buster/libssl1.1 -o "${RESULTDIR}/misc-debian-buster-relaxed.htm"
title "Evaluating Debian Buster packages (strict)"
./eval-distribution-package.sh debian buster strict libssl1.1
test -d "log-debian-buster-strict-${LOGDATE}" && ln -rs "log-debian-buster-strict-${LOGDATE}" "${RESULTDIR}/log-debian-buster-strict" || true
#title "Evaluating Debian Buster packages (relaxed)"
#./eval-distribution-package.sh debian buster relaxed libssl1.1
#test -d "log-debian-buster-relaxed-${LOGDATE}" && ln -rs "log-debian-buster-relaxed-${LOGDATE}" "${RESULTDIR}/log-debian-buster-relaxed" || true

title "Retrieving packages for Debian Bullseye"
../tools/snapshot-dates.py -a debian debian-security -s "bullseye.*" -- libssl1.1 | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq
../tools/snapshot-fetch.py -d backtesting/debian/bullseye -x libssl1.1 1.1.1c-1 1.1.1d-1 1.1.1d-2 1.1.1f-1 1.1.1g-1 1.1.1h-1 1.1.1i-1 1.1.1i-2 1.1.1i-3 1.1.1j-1 1.1.1k-1 1.1.1k-1+deb11u1 1.1.1k-1+deb11u2 1.1.1n-0+deb11u1 1.1.1n-0+deb11u2 1.1.1n-0+deb11u3 1.1.1n-0+deb11u4
title "Generating comparison table for Debian Bullseye"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -r -d -N backtesting/debian/bullseye/libssl1.1 -o "${RESULTDIR}/misc-debian-bullseye.htm"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -i -r -d -N backtesting/debian/bullseye/libssl1.1 -o "${RESULTDIR}/misc-debian-bullseye-relaxed.htm"
title "Evaluating Debian Bullseye packages (strict)"
./eval-distribution-package.sh debian bullseye strict libssl1.1
test -d "log-debian-bullseye-strict-${LOGDATE}" && ln -rs "log-debian-bullseye-strict-${LOGDATE}" "${RESULTDIR}/log-debian-bullseye-strict" || true
#title "Evaluating Debian Bullseye packages (relaxed)"
#./eval-distribution-package.sh debian bullseye relaxed libssl1.1
#test -d "log-debian-bullseye-relaxed-${LOGDATE}" && ln -rs "log-debian-bullseye-relaxed-${LOGDATE}" "${RESULTDIR}/log-debian-bullseye-relaxed" || true


title "Retrieving packages for Ubuntu Focal"
../tools/launchpad-dates.py -p release updates security proposed -s focal -- libssl1.1
../tools/launchpad-fetch.sh -V focal -d backtesting/ubuntu/focal/libssl1.1 -x libssl1.1
title "Generating comparison table for Ubuntu Focal"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -r -d -N backtesting/ubuntu/focal/libssl1.1 -o "${RESULTDIR}/misc-ubuntu-focal.htm"
bean-compare -vv -l "lib(ssl|crypto).so.1.1" -i -r -d -N backtesting/ubuntu/focal/libssl1.1 -o "${RESULTDIR}/misc-ubuntu-focal-relaxed.htm"
title "Evaluating Ubuntu Focal packages (strict)"
./eval-distribution-package.sh ubuntu focal strict libssl1.1
test -d "log-ubuntu-focal-strict-${LOGDATE}" && ln -rs "log-ubuntu-focal-strict-${LOGDATE}" "${RESULTDIR}/log-ubuntu-focal-strict" || true
#title "Evaluating Ubuntu Focal packages (relaxed)"
#./eval-distribution-package.sh ubuntu focal relaxed libssl1.1
#test -d "log-ubuntu-focal-relaxed-${LOGDATE}" && ln -rs "log-ubuntu-focal-relaxed-${LOGDATE}" "${RESULTDIR}/log-ubuntu-focal-relaxed" || true



title "Done"
echo "For results see ${RESULTDIR}"

# Open result folder on desktop
if [[ -n "${DISPLAY}" ]] ; then
	xdg-open "${RESULTDIR}" >/dev/null 2>&1 &
fi

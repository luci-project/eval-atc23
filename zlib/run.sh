#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cd "$DIR"

EVALNAME="Zlib"

source ../tools/run-config.sh

## Vanilla

if echo release/* | xargs -n1 test -e ; then
	echo "All libraries seem to exist -- cleanup for rebuild!"
else
	title "Building libraries"
	./gen-lib.sh v1.2.0{,.{1..8}} v1.2.1{,.1,.2} v1.2.2{,.{1..4}} v1.2.3{,.{1..9}} v1.2.4{,.{1..5}} v1.2.5{,.{1..3}} v1.2.6{,.1} v1.2.7{,.{1..3}} v1.2.{8..13}
fi

title "Generating comparison tables"
bean-compare -vv -l libz.so.1 -r -d -s release -o "${RESULTDIR}/misc-compatibility-vanilla-with-dwarf.htm"
bean-compare -vv -l libz.so.1 -r -d -N release -o "${RESULTDIR}/misc-compatibility-vanilla-elf-only.htm"

if [[ ! -x test/runtests ]] ; then
	title "Building test binary"
	./gen-test.sh v1.2.13
fi

title "Evaluating Vanilla Baseline"
./eval-vanilla.sh baseline v1.2.0 v1.2.13
test -d "log-vanilla-baseline-${LOGDATE}" && ln -rs "log-vanilla-baseline-${LOGDATE}" "${RESULTDIR}/log-vanilla-baseline" || true
test -f "log-vanilla-baseline-${LOGDATE}/run-summary.txt" && ln -rs "log-vanilla-baseline-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-vanilla-baseline.txt"

title "Evaluating Vanilla Luci"
./eval-vanilla.sh test v1.2.0 v1.2.13
test -d "log-vanilla-test-${LOGDATE}" && ln -rs "log-vanilla-test-${LOGDATE}" "${RESULTDIR}/log-vanilla-test" || true
test -f "log-vanilla-test-${LOGDATE}/run-summary.txt" && ln -rs "log-vanilla-test-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-vanilla-luci.txt"


## Backtesting

title "Retrieving packages for Debian Buster"
../tools/snapshot-dates.py -a debian debian-security -s "buster.*" -- zlib1g | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq
../tools/snapshot-fetch.py -d backtesting/debian/buster -x zlib1g 1:1.2.8.dfsg-5 1:1.2.11.dfsg-1 1:1.2.11.dfsg-1+deb10u1 1:1.2.11.dfsg-1+deb10u2
title "Generating comparison table for Debian Buster"
bean-compare -v -l libz.so.1 -r -d -N backtesting/debian/buster/zlib1g  -o "${RESULTDIR}/misc-debian-buster-elf-section.htm"
title "Evaluating Debian Buster packages"
./eval-distribution-package.sh debian buster zlib1g
test -d "log-debian-buster-${LOGDATE}" && ln -rs "log-debian-buster-${LOGDATE}" "${RESULTDIR}/log-debian-buster" || true
test -f "log-debian-buster-${LOGDATE}/run-summary.txt" && ln -rs "log-debian-buster-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-debian-buster-luci.txt"


title "Retrieving packages for Debian Bullseye"
../tools/snapshot-dates.py -a debian debian-security -s "bullseye.*" -- zlib1g | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq
../tools/snapshot-fetch.py -d backtesting/debian/bullseye -x zlib1g 1:1.2.11.dfsg-1 1:1.2.11.dfsg-1+b1 1:1.2.11.dfsg-1.2 1:1.2.11.dfsg-2 1:1.2.11.dfsg-2+deb11u1 1:1.2.11.dfsg-2+deb11u2
title "Generating comparison table for Debian Bullseye"
bean-compare -v -l libz.so.1 -r -d -N backtesting/debian/bullseye/zlib1g  -o "${RESULTDIR}/misc-debian-bullseye-elf-section.htm"
title "Evaluating Debian Bullseye packages"
./eval-distribution-package.sh debian bullseye zlib1g
test -d "log-debian-bullseye-${LOGDATE}" && ln -rs "log-debian-bullseye-${LOGDATE}" "${RESULTDIR}/log-debian-bullseye" || true
test -f "log-debian-bullseye-${LOGDATE}/run-summary.txt" && ln -rs "log-debian-bullseye-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-debian-bullseye-luci.txt"


title "Retrieving packages for Ubuntu Focal"
../tools/launchpad-dates.py -p release updates security proposed -s focal -- zlib1g
../tools/launchpad-fetch.sh -V focal -d backtesting/ubuntu/focal/zlib1g -x zlib1g
title "Generating comparison table for Ubuntu Focal"
bean-compare -v -l libz.so.1 -r -d -N backtesting/ubuntu/focal/zlib1g  -o "${RESULTDIR}/misc-ubuntu-focal-elf-section.htm"
title "Evaluating Ubuntu Focal packages"
./eval-distribution-package.sh ubuntu focal zlib1g
test -d "log-ubuntu-focal-${LOGDATE}" && ln -rs "log-ubuntu-focal-${LOGDATE}" "${RESULTDIR}/log-ubuntu-focal" || true
test -f "log-ubuntu-focal-${LOGDATE}/run-summary.txt" && ln -rs "log-ubuntu-focal-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-ubuntu-focal-luci.txt"

title "Retrieving packages for Ubuntu Jammy"
# Must run on a platform with dpkg supporting zstd -- e.g. ubuntu focal
../tools/launchpad-dates.py -p release updates security proposed -s jammy -- zlib1g
../tools/launchpad-fetch.sh -V jammy -d backtesting/ubuntu/jammy/zlib1g -x zlib1g
title "Generating comparison table for Ubuntu Jammy"
bean-compare -v -l libz.so.1 -r -d -N backtesting/ubuntu/jammy/zlib1g  -o "${RESULTDIR}/misc-ubuntu-jammy-elf-section.htm"
title "Evaluating Ubuntu Jammy packages"
./eval-distribution-package.sh ubuntu jammy zlib1g
test -d "log-ubuntu-jammy-${LOGDATE}" && ln -rs "log-ubuntu-jammy-${LOGDATE}" "${RESULTDIR}/log-ubuntu-jammy" || true
test -f "log-ubuntu-jammy-${LOGDATE}/run-summary.txt" && ln -rs "log-ubuntu-jammy-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-ubuntu-jammy-luci.txt"

# generating summary
./summary-distribution-package.sh log-{vanilla-test,debian-buster,debian-bullseye,ubuntu-focal,ubuntu-jammy}-${LOGDATE} > "${RESULTDIR}/table5-distribution-package-summary.txt"

title "Done"
echo "For results see ${RESULTDIR}"

# Open result folder on desktop
if [[ -n "${DISPLAY}" ]] ; then
	xdg-open "${RESULTDIR}" >/dev/null 2>&1 &
fi
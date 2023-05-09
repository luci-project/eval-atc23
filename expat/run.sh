#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cd "$DIR"

EVALNAME="Expat"

source ../tools/run-config.sh

## Vanilla

if echo release/* | xargs -n1 test -e ; then
	echo "All libraries seem to exist -- cleanup for rebuild!"
else
	title "Building libraries"
	./gen-lib.sh R_2_{0,1}_{0,1} R_2_2_{0..10} R_2_3_0 R_2_4_{0..9} R_2_5_0
fi

title "Generating comparison tables"
bean-compare -vv -l libexpat.so.1 -r -d -s release -o "${RESULTDIR}/table1-compatibility-vanilla-with-dwarf.htm"
bean-compare -vv -l libexpat.so.1 -r -d -N release -o "${RESULTDIR}/table1-compatibility-vanilla-elf-only.htm"

if [[ ! -x test/runtests ]] ; then
	title "Building test binary"
	./gen-test.sh R_2_4_0
fi

title "Evaluating Vanilla Baseline"
./eval-vanilla.sh baseline 2.0.0 2.5.0
test -d "log-vanilla-baseline-${LOGDATE}" && ln -rs "log-vanilla-baseline-${LOGDATE}" "${RESULTDIR}/log-vanilla-baseline" || true
test -f "log-vanilla-baseline-${LOGDATE}/run-summary.txt" && ln -rs "log-vanilla-baseline-${LOGDATE}/run-summary.txt" "${RESULTDIR}/table1-run-vanilla-baseline.txt"

title "Evaluating Vanilla Luci"
./eval-vanilla.sh test 2.0.0 2.5.0
test -d "log-vanilla-test-${LOGDATE}" && ln -rs "log-vanilla-test-${LOGDATE}" "${RESULTDIR}/log-vanilla-test" || true
test -f "log-vanilla-test-${LOGDATE}/run-summary.txt" && ln -rs "log-vanilla-test-${LOGDATE}/run-summary.txt" "${RESULTDIR}/table1-run-vanilla-luci.txt"


## Backtesting

title "Retrieving packages for Debian Buster"
# There are some packages missing in the metasnap dates list
../tools/snapshot-dates.py -a debian debian-security -s "buster.*" -- libexpat1 | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq
../tools/snapshot-fetch.py -d backtesting/debian/buster -x libexpat1 2.2.0-2 2.2.1-{1,2,3} 2.2.2-{1,2} 2.2.3-{1,2} 2.2.5-{1,2,3} 2.2.6-{1,2} 2.2.6-2+deb10u{1,2,3,4,5,6}
title "Generating comparison table for Debian Buster"
bean-compare -v -l libexpat.so.1 -r -d -N backtesting/debian/buster/libexpat1  -o "${RESULTDIR}/table2-debian-buster-elf-section.htm"
title "Evaluating Debian Buster packages"
./eval-distribution-package.sh debian buster libexpat1
test -d "log-debian-buster-${LOGDATE}" && ln -rs "log-debian-buster-${LOGDATE}" "${RESULTDIR}/log-debian-buster" || true
test -f "log-debian-buster-${LOGDATE}/run-summary.txt" && ln -rs "log-debian-buster-${LOGDATE}/run-summary.txt" "${RESULTDIR}/table2-run-debian-buster-luci.txt"


title "Retrieving packages for Debian Bullseye"
../tools/snapshot-dates.py -a debian debian-security -s "bullseye.*" -- libexpat1 | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq
../tools/snapshot-fetch.py -d backtesting/debian/bullseye -x libexpat1 2.2.6-2 2.2.7-{1,2} 2.2.9-1 2.2.10-{1,2} 2.2.10-2+deb11u{1,2,3,4,5}
title "Generating comparison table for Debian Bullseye"
bean-compare -v -l libexpat.so.1 -r -d -N backtesting/debian/bullseye/libexpat1  -o "${RESULTDIR}/table2-debian-bullseye-elf-section.htm"
title "Evaluating Debian Bullseye packages"
./eval-distribution-package.sh debian bullseye libexpat1
test -d "log-debian-bullseye-${LOGDATE}" && ln -rs "log-debian-bullseye-${LOGDATE}" "${RESULTDIR}/log-debian-bullseye" || true
test -f "log-debian-bullseye-${LOGDATE}/run-summary.txt" && ln -rs "log-debian-bullseye-${LOGDATE}/run-summary.txt" "${RESULTDIR}/table2-run-debian-bullseye-luci.txt"


title "Retrieving packages for Ubuntu Focal"
../tools/launchpad-dates.py -s focal -- libexpat1
../tools/launchpad-fetch.sh -V focal -d backtesting/ubuntu/focal/libexpat1 -x libexpat1
title "Generating comparison table for Ubuntu Focal"
bean-compare -v -l libexpat.so.1 -r -d -N backtesting/ubuntu/focal/libexpat1  -o "${RESULTDIR}/misc-ubuntu-focal-elf-section.htm"
title "Evaluating Ubuntu Focal packages"
./eval-distribution-package.sh ubuntu focal libexpat1
test -d "log-ubuntu-focal-${LOGDATE}" && ln -rs "log-ubuntu-focal-${LOGDATE}" "${RESULTDIR}/log-ubuntu-focal" || true
test -f "log-ubuntu-focal-${LOGDATE}/run-summary.txt" && ln -rs "log-ubuntu-focal-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-ubuntu-focal-luci.txt"

title "Retrieving packages for Ubuntu Jammy"
# Must run on a platform with dpkg supporting zstd -- e.g. ubuntu focal
../tools/launchpad-dates.py -s jammy -- libexpat1
../tools/launchpad-fetch.sh -V jammy -d backtesting/ubuntu/jammy/libexpat1 -x libexpat1
title "Generating comparison table for Ubuntu Jammy"
bean-compare -v -l libexpat.so.1 -r -d -N backtesting/ubuntu/jammy/libexpat1  -o "${RESULTDIR}/misc-ubuntu-jammy-elf-section.htm"
title "Evaluating Ubuntu Jammy packages"
./eval-distribution-package.sh ubuntu jammy libexpat1
test -d "log-ubuntu-jammy-${LOGDATE}" && ln -rs "log-ubuntu-jammy-${LOGDATE}" "${RESULTDIR}/log-ubuntu-jammy" || true
test -f "log-ubuntu-jammy-${LOGDATE}/run-summary.txt" && ln -rs "log-ubuntu-jammy-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-ubuntu-jammy-luci.txt"

# generating summary
./summary-distribution-package.sh log-{vanilla-test,debian-buster,debian-bullseye,ubuntu-focal,ubuntu-jammy}-${LOGDATE} > "${RESULTDIR}/table3-distribution-package-summary.txt"

title "Done"
echo "For results see ${RESULTDIR}"

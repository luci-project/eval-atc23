#!/bin/bash

DIR="$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

cd "$DIR"

EVALNAME="libxcrypt"

source ../tools/run-config.sh

## Vanilla

if echo release/* | xargs -n1 test -e ; then
	echo "All libraries seem to exist -- cleanup for rebuild!"
else
	title "Building libraries"
	./gen-lib.sh v4.0.{0,1} v4.1.{0..2} v4.2.{0..3} v4.3.{0..4} v4.4.{0..33}
fi

title "Generating comparison tables"
bean-compare -vv -l libcrypt.so.1 -r -d -s release -o "${RESULTDIR}/misc-compatibility-vanilla-with-dwarf.htm"
bean-compare -vv -l libcrypt.so.1 -r -d -N release -o "${RESULTDIR}/misc-compatibility-vanilla-elf-only.htm"

title "Building test binary"
./gen-test.sh v4.4.33

title "Evaluating Vanilla Baseline"
./eval-vanilla.sh baseline 4.0.0 4.4.33
test -d "log-vanilla-baseline-${LOGDATE}" && ln -rs "log-vanilla-baseline-${LOGDATE}" "${RESULTDIR}/log-vanilla-baseline" || true
test -f "log-vanilla-baseline-${LOGDATE}/run-summary.txt" && ln -rs "log-vanilla-baseline-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-vanilla-baseline.txt"

title "Evaluating Vanilla Luci"
./eval-vanilla.sh test 4.0.0 4.4.33
test -d "log-vanilla-test-${LOGDATE}" && ln -rs "log-vanilla-test-${LOGDATE}" "${RESULTDIR}/log-vanilla-test" || true
test -f "log-vanilla-test-${LOGDATE}/run-summary.txt" && ln -rs "log-vanilla-test-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-vanilla-luci.txt"


## Backtesting

title "Retrieving packages for Debian Bullseye"
# There are some packages missing in the metasnap dates list
../tools/snapshot-dates.py -a debian -s "bullseye.*" -- libcrypt1 | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq
../tools/snapshot-fetch.py -d backtesting/debian/bullseye -x libcrypt1 1:4.4.10-10 1:4.4.15-1 1:4.4.16-1 1:4.4.17-1 1:4.4.18-1 1:4.4.18-2 1:4.4.18-3 1:4.4.18-4
# Structure should be the same for our scripts
mv backtesting/debian/bullseye/libcrypt1/1:4.4.18-3/lib backtesting/debian/bullseye/libcrypt1/1:4.4.18-3/usr/
mv backtesting/debian/bullseye/libcrypt1/1:4.4.18-4/lib backtesting/debian/bullseye/libcrypt1/1:4.4.18-4/usr/
title "Generating comparison table for Debian Bullseye"
bean-compare -v -l libcrypt.so.1 -r -d -N backtesting/debian/bullseye/libcrypt1 -o "${RESULTDIR}/misc-debian-bullseye-elf-section.htm"
title "Evaluating Debian Bullseye packages"
./eval-distribution-package.sh debian bullseye libcrypt1
test -d "log-debian-bullseye-${LOGDATE}" && ln -rs "log-debian-bullseye-${LOGDATE}" "${RESULTDIR}/log-debian-bullseye" || true
test -f "log-debian-bullseye-${LOGDATE}/run-summary.txt" && ln -rs "log-debian-bullseye-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-debian-bullseye-luci.txt"


title "Retrieving packages for Ubuntu Focal"
../tools/launchpad-dates.py -s focal -- libcrypt1
../tools/launchpad-fetch.sh -V focal -d backtesting/ubuntu/focal/libcrypt1 -x libcrypt1
# Structure should be the same for our scripts
mv backtesting/ubuntu/focal/libcrypt1/1:4.4.10-10ubuntu4/lib backtesting/ubuntu/focal/libcrypt1/1:4.4.10-10ubuntu4/usr
mv backtesting/ubuntu/focal/libcrypt1/1:4.4.10-10ubuntu5/lib backtesting/ubuntu/focal/libcrypt1/1:4.4.10-10ubuntu5/usr
title "Generating comparison table for Ubuntu Focal"
bean-compare -v -l libcrypt.so.1 -r -d -N backtesting/ubuntu/focal/libcrypt1 -o "${RESULTDIR}/misc-ubuntu-focal-elf-section.htm"
title "Evaluating Ubuntu Focal packages"
./eval-distribution-package.sh ubuntu focal libcrypt1
test -d "log-ubuntu-focal-${LOGDATE}" && ln -rs "log-ubuntu-focal-${LOGDATE}" "${RESULTDIR}/log-ubuntu-focal" || true
test -f "log-ubuntu-focal-${LOGDATE}/run-summary.txt" && ln -rs "log-ubuntu-focal-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-ubuntu-focal-luci.txt"

title "Retrieving packages for Ubuntu Jammy"
# Must run on a platform with dpkg supporting zstd -- e.g. ubuntu focal
../tools/launchpad-dates.py -s jammy -- libcrypt1
../tools/launchpad-fetch.sh -V jammy -d backtesting/ubuntu/jammy/libcrypt1 -x libcrypt1
title "Generating comparison table for Ubuntu Jammy"
bean-compare -v -l libcrypt1.so.1 -r -d -N backtesting/ubuntu/jammy/libcrypt1 -o "${RESULTDIR}/misc-ubuntu-jammy-elf-section.htm"
title "Evaluating Ubuntu Jammy packages"
./eval-distribution-package.sh ubuntu jammy libcrypt1
test -d "log-ubuntu-jammy-${LOGDATE}" && ln -rs "log-ubuntu-jammy-${LOGDATE}" "${RESULTDIR}/log-ubuntu-jammy" || true
test -f "log-ubuntu-jammy-${LOGDATE}/run-summary.txt" && ln -rs "log-ubuntu-jammy-${LOGDATE}/run-summary.txt" "${RESULTDIR}/misc-run-ubuntu-jammy-luci.txt"

# generating summary
./summary-distribution-package.sh log-{vanilla-test,debian-buster,debian-bullseye,ubuntu-focal,ubuntu-jammy}-${LOGDATE} > "${RESULTDIR}/table3-distribution-package-summary.txt"

title "Done"
echo "For results see ${RESULTDIR}"



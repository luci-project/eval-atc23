zlib Experiment
===============

The compression library [zlib](https://www.zlib.net/) was used in *Luci*'s evaluation due to the following attributes:

 * [popular](https://qa.debian.org/popcon.php?package=zlib) and very widely used: ranked #11 of [most installed debian packages](https://popcon.debian.org/by_inst)
 * [several releases](https://github.com/madler/zlib/tags) since 2011
 * some [vulnerabilities](https://www.cvedetails.com/product/111843/Zlib-Zlib.html?vendor_id=13265)
 * decent [test example](https://github.com/madler/zlib/tree/master/test)

We evaluate *Luci* with the test suite using custom (vanilla) library builds, and the corresponding packages distributed by Debian and Ubuntu.


Preparation
-----------

We strongly recommend using a standard installation of *Ubuntu Focal* (due to the compatibility with Ubuntu's package compression method) with no modifications regarding the system configuration for the artifact evaluation.

[Docker Engine](https://docs.docker.com/engine/install/ubuntu/) is required for building and testing (using the [official Debian Bullseye Docker image](https://hub.docker.com/_/debian)).

You have to set up the environment by building and installing *Luci* and its submodules:

    ../setup.sh

In case you have already performed evaluation runs and want to start over again, you can remove its artifacts from this directory by executing

    ./cleanup.sh

The following documentation contains a detailed description of the steps to reproduce the zlib artifacts of the paper.

However, all steps described bellow can also be automatically executed with

    ./run.sh

The experiment will take approximately **45 minutes** to complete.

In the end, the results of all individual tests (baseline, vanilla, and backtesting) are stored in a `result-DATE` directory.

> **Please note:** The *failed test cases* in the `run-` output files do not refer to issues with *Luci* but to bugs in older libraries and, hence, are expected.
> These *failed test cases* can be seen in the baseline as well and, when using dynamic updates via *Luci*. These failed tests reduce with increasing library version.

> **Please note:** The default time limit before old library code is considered *obsolete* is set to 3 seconds after a new version is applied.
> Depending on your system and the load during execution of the test application, this may cause false detections.
> Please consider increasing the delay in `LD_DETECT_OUTDATED_DELAY` by editing `run-test.sh` if the problem persists on your system.

The file prefixed with `table5` corresponds to table 5 in the paper.


Vanilla Build
-------------

Testing a range of official releases.

### Build Libraries

The build process is performed in a fresh environment using the [official Debian Bullseye Docker image](https://hub.docker.com/_/debian) and installing the necessary build utilities

    apt-get install -y git gcc cmake

Libraries are built from the official [repository](https://github.com/madler/zlib).
For `configure`, only the `--shared` (for shared library build) and `--prefix` parameter (to adjust the installation directory) will be set.

To speed up build several releases, we can avoid restarting the container (retrieving the repository & installing build utilities) by using a separate build directory, which gets deleted after finishing the build.
This prevents the build system from using artifacts of previous builds.

The whole process is automated in `gen-lib.sh`, which takes the git tags of releases to build as parameter.
For the evaluation, all releases of version 1.2 are taken into account:

    ./gen-lib.sh v1.2.0{,.{1..8}} v1.2.1{,.1,.2} v1.2.2{,.{1..4}} v1.2.3{,.{1..9}} v1.2.4{,.{1..5}} v1.2.5{,.{1..3}} v1.2.6{,.1} v1.2.7{,.{1..3}} v1.2.{8..13}

This will create folders with the git commit hash (40 character long hex value) as name.
For convenience, the folder `release/` contains symbolic links with the git tag names to the corresponding library folder.

#### Bug in v1.2.5.1 preventing build

The release 1.2.5.1 has an issue in the build system not building/installing the shared library.

We have to perform the step manually by executing

    make CFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" SFLAGS="-O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN" SHAREDLIB=libz.so SHAREDLIBV=libz.so.1.2.5.1 SHAREDLIBM=libz.so.1 shared
    gcc -O3 -g -fPIC -D_LARGEFILE64_SOURCE=1 -DHAVE_HIDDEN -o libz.so.1.2.5.1 adler32.lo compress.lo crc32.lo deflate.lo gzclose.lo gzlib.lo gzread.lo gzwrite.lo infback.lo inffast.lo inflate.lo inftrees.lo trees.lo uncompr.lo zutil.lo -shared -lc

and copying `libz.so.1.2.5.1` to the target `/lib` folder and creating the symlinking `libz.so` and `libz.so.1` to it.


### Build Test Suite

Several tests are performed in the official [example](https://github.com/madler/zlib/blob/master/test/example.c).

We have modified the source file to execute the tests in an endless loop, and instead of process termination (`exit()`) functions now return values signaling a failure.
The revised version is located in the `src-test` directory.

The script `gen-test.sh` builds the test suite within a Debian Bullseye Docker image, using the official repository for includes and a previously build library to link against:

    ./gen-test.sh v1.2.13

After completion, the resulting test binary is stored in `test/runtests`.


### Measure Baseline

For every library version, we start the test application using the system's default RTLD, which dynamically links it against the corresponding shared library build, and kill it after approx. 15 seconds, continuing with the next version.

The `run-baseline.sh` script performs this inside a Docker container with a Debian Bullseye image.
It is called by

    ./eval-vanilla.sh baseline v1.2.0 v1.2.13

and stores the artifacts (logs) in a directory with the format `log-vanilla-baseline-DATE-TIME`:
The output of the test application `run-*.log` contains the results for the baseline measurement.


### Dynamic Updates with Luci

Since DWARF debug information should be considered, we first start the `bean-elfvarsd` service (hashing information from the debug symbols) which listens on a local TCP port (9001) for queries from *Luci*.
The tests itself are performed inside a Docker container with a Debian Bullseye image:

Initially, a symbolic link to the first version of the library.
The interpreter of the test application is modified to start with *Luci* instead of the system RTLD (using `elfo-setinterp`).

*Luci*'s configuration is stored in environmental variables:
 * dynamic updates are enabled
 * detection of outdated code (using *userfaultfd*) is enabled
 * debug output stored to `luci.log`
 * status info with information about successful and rejected dynamic updates are stored in a `status,info` file
 * connection information for `bean-elfvarsd` service is set

Then the test application is executed.
After a certain time, the symbolic link is modified to point to the subsequent version of the library (and noted with timestamp in `link.log`).

*Luci* should now detect the change (employing *inotify*), check the compatibility (including querying `bean-elfvarsd`), and then either perform the update to the new version or discard it and continue the test application with the previous version.
In either case, it writes to `status.info` (`SUCCESS` or `FAILED`).

The control script `run-test.sh` will check this status file after a few seconds:
If it detects a failure, it will kill the test application and restart it - which will dynamically link it with the current version.
This causes the `run`-logfile to rotate.

In any case, the control script will continue after a certain amount of time with the next library version and repeat the steps, until all versions have been checked.

To start the described testing setup, run

    ./eval-vanilla.sh test v1.2.0 v1.2.13

The artifacts (logs) are stored in a directory with the format `log-vanilla-test-DATE-TIME`:



Backtesting Distribution Packages
---------------------------------

The previously generated test application is dynamically linked against official *zlib1g* packages in [Debian](https://www.debian.org/) ([Buster](https://www.debian.org/releases/buster/) & [Bullseye](https://www.debian.org/releases/bullseye/)), and [Ubuntu](https://ubuntu.com/) ([Focal](https://releases.ubuntu.com/focal/) & [Jammy](https://releases.ubuntu.com/jammy/)).

For each release of a distribution, we test all published builds (during development phase and after stable release) by starting with the first build and replacing it with the subsequent builds after a certain time.
If an update cannot be applied, the test application is restarted, dynamically linked against the build causing the incompatibility, and the replacement starts again.

But before starting the test, we have to retrieve the all published builds from the official archives and extract them.

> **Please note:** Since the scripts employ the [Debian package manager](https://en.wikipedia.org/wiki/Dpkg) for extracting the contents of each package, this should run on a debianoid distribution. We recommend Ubuntu Focal due to the compatibility.

> **Please note:** Since we are not able to retrieve debug symbols for each build (they are sometimes missing in the archives, backtesting does not use DWARF hashing and work on the binaries only.


### Retrieving the packages in Debian

With the help of the [metasnap.debian.net](https://metasnap.debian.net/), we are able to determine the date a certain version was published.
Using this date in conjunction with the [snapshot.debian.org](https://snapshot.debian.org/) service, we are, in turn, able to download old revisions of an official package.

> **Please note:** The snapshot service has a [not so well-documented rate limit](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=977653) for its service. We therefore strongly recommend downloading the packages only once. If you encounter a rate limit, please try again after a certain time.


#### Buster (10)

Debian Buster has the following builds for [`zlib1g`](https://packages.debian.org/buster/zlib1g):
   1. Build `1:1.2.8.dfsg-5`
   2. Build `1:1.2.11.dfsg-1`
   3. Build `1:1.2.11.dfsg-1+deb10u1`
   4. Build `1:1.2.11.dfsg-1+deb10u2`


You can check the list of builds by [using metasnap](https://metasnap.debian.net/cgi-bin/api?archive=debian&pkg=zlib1g&arch=amd64) with

    ../tools/snapshot-dates.py -a debian debian-security -s "buster.*" -- zlib1g

Download and extract the builds using

    ../tools/snapshot-fetch.py -d backtesting/debian/buster -x zlib1g 1:1.2.8.dfsg-5 1:1.2.11.dfsg-1 1:1.2.11.dfsg-1+deb10u1 1:1.2.11.dfsg-1+deb10u2

Start the evaluation of the packages with

    ./eval-distribution-package.sh debian buster zlib1g

The summarized results of the test application are stored in `run-summary.txt`.


#### Bullseye (11)

Debian Bullseye has the following builds for [`zlib1g`](https://packages.debian.org/bullseye/zlib1g):
   1. Build `1:1.2.11.dfsg-1`
   2. Build `1:1.2.11.dfsg-1+b1`
   3. Build `1:1.2.11.dfsg-1.2`
   4. Build `1:1.2.11.dfsg-2`
   5. Build `1:1.2.11.dfsg-2+deb11u1`
   6. Build `1:1.2.11.dfsg-2+deb11u2`

You can check the list of builds by [using metasnap](https://metasnap.debian.net/cgi-bin/api?archive=debian&pkg=zlib1g&arch=amd64) with

    ../tools/snapshot-dates.py -a debian debian-security -s "bullseye.*" -- zlib1g

Download and extract the builds using

    ../tools/snapshot-fetch.py -d backtesting/debian/bullseye -x zlib1g 1:1.2.11.dfsg-1 1:1.2.11.dfsg-1+b1 1:1.2.11.dfsg-1.2 1:1.2.11.dfsg-2 1:1.2.11.dfsg-2+deb11u1 1:1.2.11.dfsg-2+deb11u2

Start the evaluation of the packages with

    ./eval-distribution-package.sh debian bullseye zlib1g

The summarized results of the test application are stored in `run-summary.txt`.


### Retrieving the packages in Ubuntu

The all official revisions can be found on [Canonical Launchpad](https://launchpad.net/).


#### Focal Fossa (20.04)

Ubuntu Focal has the following builds for [`zlib1g`](https://packages.ubuntu.com/focal/zlib1g):
   1. Build `1:1.2.11.dfsg-1.2ubuntu1`
   2. Build `1:1.2.11.dfsg-1ubuntu3`
   3. Build `1:1.2.11.dfsg-2ubuntu1`
   4. Build `1:1.2.11.dfsg-2ubuntu1.1`
   5. Build `1:1.2.11.dfsg-2ubuntu1.2`
   6. Build `1:1.2.11.dfsg-2ubuntu1.3`
   7. Build `1:1.2.11.dfsg-2ubuntu1.4`
   8. Build `1:1.2.11.dfsg-2ubuntu1.5`

You can check the list of builds on [Launchpad](https://launchpad.net/ubuntu/focal/amd64/zlib1g) or with

    ../tools/launchpad-dates.py -p release updates security proposed -s focal -- zlib1g

Download and extract the builds using

    ../tools/launchpad-fetch.sh -V focal -d backtesting/ubuntu/focal/zlib1g -x zlib1g

Start the evaluation of the packages with

    ./eval-distribution-package.sh ubuntu focal zlib1g

The summarized results of the test application are stored in `run-summary.txt`.


#### Jammy Jellyfish (22.04)

Ubuntu Focal has the following builds for [`zlib1g`](https://packages.ubuntu.com/jammy/zlib1g):
   1. Build `1:1.2.11.dfsg-2ubuntu7`
   2. Build `1:1.2.11.dfsg-2ubuntu8`
   3. Build `1:1.2.11.dfsg-2ubuntu9`
   4. Build `1:1.2.11.dfsg-2ubuntu9.1`
   5. Build `1:1.2.11.dfsg-2ubuntu9.2`

You can check the list of builds on [Launchpad](https://launchpad.net/ubuntu/jammy/amd64/zlib1g) or with

    ../tools/launchpad-dates.py -p release updates security proposed -s jammy -- zlib1g

Download and extract the builds using

    ../tools/launchpad-fetch.sh -V jammy -d backtesting/ubuntu/jammy/zlib1g -x zlib1g

> **Please note:** Jammy packages are compressed using [zstd](https://de.wikipedia.org/wiki/Zstandard), which must be supported by the [Debian package manager (`dpkg`)](https://en.wikipedia.org/wiki/Dpkg). This is the case for Ubuntu Focal and Jammy - please run this command on such a platform (or use a container)

Start the evaluation of the packages with

    ./eval-distribution-package.sh ubuntu jammy zlib1g

The summarized results of the test application are stored in `run-summary.txt`.


### Summary

By using the files `link.log` and `status.log` in each log folder, we can generate a summary as shown in Table 5:

    ./summary-distribution-package.sh log-{vanilla-test,debian,ubuntu}-*

To verify this table, the Docker output (`out-docker.log`) might be the most human-readable way of the evaluation output.

The script is not able to calculate the values for *unique* releases, this was done manually in Table 5 with the help of `bean-compare`:

    bean-compare -v -l libz.so.1 -r -d -N backtesting/ubuntu/jammy/zlib1g

would output
 
| 1:1.2.11.dfsg-2ubuntu7 | 1:1.2.11.dfsg-2ubuntu8 | 1:1.2.11.dfsg-2ubuntu9 | 1:1.2.11.dfsg-2ubuntu9.1 | 1:1.2.11.dfsg-2ubuntu9.2 |
|------------------------|------------------------|------------------------|--------------------------|--------------------------|
| *(update)*             | *update*               | *update*               | *update*                 | *update*                 |
|                        | .build-id              | .build-id              | .build-id                | .build-id                |
|                        |                        | .text                  |                          | .text                    |
|                        |                        | .rodata                |                          | .rodata                  |
|                        |                        | .relro                 |                          | .relro                   |

which indicates, that `1:1.2.11.dfsg-2ubuntu8` and `1:1.2.11.dfsg-2ubuntu9.1` have a different Build ID, but all sections relevant for execution have not changed.
Hence, we have only three *unique* versions with actual changes: `1:1.2.11.dfsg-2ubuntu7`, `1:1.2.11.dfsg-2ubuntu9` and `1:1.2.11.dfsg-2ubuntu9.2`.

However, in the evaluation all four updates have been performed.

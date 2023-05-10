libxcrypt Experiment
====================

The one-way hashing library [libxcrypt](https://github.com/besser82/libxcrypt) was used in Evaluation due to the following attributes 

 * increasingly [popular](https://qa.debian.org/popcon.php?package=libxcrypt) alternative for glibcs `libcrypt.so.1`
 * [many recent releases](https://github.com/besser82/libxcrypt/releases)
 * excellent [test suite](https://github.com/besser82/libxcrypt/tree/develop/test)

We evaluate *Luci* with the test suite using custom (vanilla) library builds, and the corresponding packages distributed by Debian and Ubuntu.

For this evaluation, multithreading (via `pthread`) is used to executed test cases in parallel.
Therefore, we recommend at least 4 physical cores and a solid amount of memory (8 GB).

While the overall design of the test case will stress the system a lot, it demonstrates the applicability of the DSU approach in multithreaded applications.

Preparation
-----------

We strongly recommend using a standard installation of *Ubuntu Focal* (due to the compatibility with Ubuntu's package compression method) with no modifications regarding the system configuration for the artifact evaluation.

[Docker Engine](https://docs.docker.com/engine/install/ubuntu/) is required for building and testing (using the [official Debian Bullseye Docker image](https://hub.docker.com/_/debian)).

You have to set up the environment by building and installing *Luci* and its submodules:

    ../setup.sh

In case you have already performed evaluation runs and want to start over again, you can remove its artifacts from this directory by executing

    ./cleanup.sh

The following documentation contains a detailed description of the steps to reproduce the libxcrypt artifacts of the paper.

However, all steps described bellow can also be automatically executed with

    ./run.sh

In the end, the results of all individual tests (baseline, vanilla, and backtesting) are stored in a `result-DATE` directory.

> **Please note:** The *failed test cases* in the `run-` output files do not refer to issues with *Luci* but to bugs in older libraries and, hence, are expected.
> These *failed test cases* can be seen in the baseline as well and, when using dynamic updates via *Luci*. These failed tests reduce with increasing library version.

The file prefixed with `table4` correspond to table 4 in the paper.



Vanilla Build
-------------

Testing a range of official releases.

### Build Libraries

The build process is performed in a fresh environment using the [official Debian Bullseye Docker image](https://hub.docker.com/_/debian) and installing the necessary build utilities

    apt-get install -y git gcc make perl autoconf libtool pkgconf

Libraries are built from the official [repository](https://github.com/besser82/libxcrypt/).
For `configure`, we only set the `--prefix` parameter (to adjust the installation directory) and disable treating warnings as errors (with `--disable-werror`)

To speed up build several releases, we can avoid restarting the container (retrieving the repository & installing build utilities) by using a separate build directory, which gets deleted after finishing the build.
This prevents the build system from using artifacts of previous builds.

The whole process is automated in `gen-lib.sh`, which takes the git tags of releases to build as parameter.
For the evaluation, all releases of version 4 are taken into account:

    ./gen-lib.sh v4.0.{0,1} v4.1.{0..2} v4.2.{0..3} v4.3.{0..4} v4.4.{0..33}

This will create folders with the git commit hash (40 character long hex value) as name.
For convenience, the folder `release/` contains symbolic links with the git tag names to the corresponding library folder.


### Build Test Suite

The official [test suite](https://github.com/besser82/libxcrypt) contains several independent (standalone) tests which are intended to be executed by a Perl script.

We have to exclude the tests `crypt-badargs`, `explicit-bzero` and `gensalt` since they either lead to significant memory leaks or cause a division by zero when used with older library version.

For the automatically generated *known answer* tests, we employ all algorithms as the [original Makefile](https://github.com/besser82/libxcrypt/blob/v4.4.33/Makefile.am#L388) does, hence having a total of 42 different tests, with about 28 of them compatible with the external API.

> **Please note:** Several tests (most notably `alg-*` tests) do not use the API but rely on internal functions of the library - hence, they are not compatible to the shared object and won't execute. But they are not excluded, so the RTLD has to detect the unresolvable dependencies and abort loading.

The source of these tests is unmodified, but build with a slight change in the compiler flags:
They are built as shared libraries themselves by compiling with the additional flags `-fPIC -shared`.

Our test application will start a new thread for each library and open it using `dlopen` (which fails on libraries with unmet dependencies), resolving and executing its `main()` in an endless loop, measuring the runtime of each run.

Since several test cases are designed for single threaded execution and therefore do not use the reentrant library function, the test application provides a wrapper for them:

    #define strong_alias(name, aliasname) extern __typeof (name) aliasname __THROW __attribute__ ((alias (#name)))
    
    char *crypt(const char *key, const char *salt) {
        static __thread struct crypt_data data;
        return crypt_r(key, salt, &data);
    }
    strong_alias(crypt, xcrypt);

    char * crypt_gensalt(const char *prefix, unsigned long count, const char *rbytes, int nrbytes) {
        static __thread char output[CRYPT_GENSALT_OUTPUT_SIZE];
        return crypt_gensalt_rn(prefix, count, rbytes, nrbytes, output, sizeof(output));
    }
    strong_alias(crypt_gensalt, xcrypt_gensalt);

The source of the test application and build file are located in the `src-test` directory.

The script `gen-test.sh` builds the test suite within a Debian Bullseye Docker image, using the official repository for includes and a previously build library to link against:

    ./gen-test.sh v4.4.33


### Measure Baseline

For every library version, we start the test application using the system's default RTLD, which dynamically links it against the corresponding shared library build, and kill it after approx. 15 seconds, continuing with the next version.

The `run-baseline.sh` script performs this inside a Docker container with a Debian Bullseye image.
It is called by

    ./eval-vanilla.sh baseline 4.0.0 4.4.33

and stores the artifacts (logs) in a directory with the format `log-vanilla-baseline-DATE-TIME`:
The output of the test application `run-*.log` contains the results for the baseline measurement.


### Dynamic Updates with Luci

Since DWARF debug information should be considered, we first start the `bean-elfvarsd` service (hashing information from the debug symbols) which listens on a local TCP port (9001) for queries from *Luci*.
The tests itself are performed inside a Docker container with a Debian Bullseye image:

Initially, a symbolic link to the first version of the library.
The interpreter of the test application is modified to start with *Luci* instead of the system RTLD (using `elfo-setinterp`).

*Luci*'s configuration is stored in environmental variables:
 * dynamic updates are enabled
 * debug output stored to `luci.log`
 * status info with information about successful and rejected dynamic updates are stored in a `status,info` file
 * connection information for `bean-elfvarsd` service is set
 * detection of outdated code (using *userfaultfd*) is **disabled**

Then the test application is executed.

Most test cases fully utilize a CPU core -- and depending on the particular test, the execution time of a single test case will vary a lot: between 1us and 25s.
It might even happen, that a long-running test case will not finish during the time between two updates (which is not a problem at all, but might be a bit confusing in the outputs).

When taking scheduling into account and depending on the system, the detection of outdated code would need to be adjusted to a rather high value to prevent false positives.
In the interest of run time we have decided to disable userfaultfd for this test case by default allowing us a shorter runtime per test case.
However, you can change this behavior and adjust the settings by modifying the environment variables in `run-test.sh`.

After a certain time, the symbolic link is modified to point to the subsequent version of the library (and noted with timestamp in `link.log`).

*Luci* should now detect the change (employing *inotify*), check the compatibility (including querying `bean-elfvarsd`), and then either perform the update to the new version or discard it and continue the test application with the previous version.
In either case, it writes to `status.info` (`SUCCESS` or `FAILED`).

The control script `run-test.sh` will check this status file after a few seconds:
If it detects a failure, it will kill the test application and restart it - which will dynamically link it with the current version.
This causes the `run`-logfile to rotate.

In any case, the control script will continue after a certain amount of time with the next library version and repeat the steps, until all versions have been checked.

To start the described testing setup, run

    ./eval-vanilla.sh test 4.0.0 4.4.33

The artifacts (logs) are stored in a directory with the format `log-vanilla-test-DATE-TIME`:


Backtesting Distribution Packages
---------------------------------

The previously generated test application and the test cases (`.so`) are dynamically linked against official *libcrypt1* packages in [Debian](https://www.debian.org/) ([Bullseye](https://www.debian.org/releases/bullseye/)), and [Ubuntu](https://ubuntu.com/) ([Focal](https://releases.ubuntu.com/focal/) & [Jammy](https://releases.ubuntu.com/jammy/)).

[Debian Buster](https://www.debian.org/releases/buster/) is omitted since it uses glibcs libcrypt.

For each release of a distribution, we test all published builds (during development phase and after stable release) by starting with the first build and replacing it with the subsequent builds after a certain time.
If an update cannot be applied, the test application is restarted, dynamically linked against the build causing the incompatibility and the replacement starts again.

But before starting the test, we have to retrieve the all published builds from the official archives and extract them.

> **Please note:** Since the scripts employ the [Debian package manager](https://en.wikipedia.org/wiki/Dpkg) for extracting the contents of each package, this should run on a debianoid distribution. We recommend Ubuntu Focal due to the compatibility.

> **Please note:** Since we are not able to retrieve debug symbols for each build (they are sometimes missing in the archives, backtesting does not use DWARF hashing and work on the binaries only.


### Retrieving the packages in Debian

With the help of the [metasnap.debian.net](https://metasnap.debian.net/) we are able to determine the date a certain version was published, and using this information in conjunction with the [snapshot.debian.org](https://snapshot.debian.org/) service, we are able to download old revisions of an official package.

> **Please note:** The snapshot service has a [not so well-documented rate limit](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=977653) for its service. We therefore strongly recommend downloading the packages only once. If you encounter a rate limit, please try again after a certain time.

#### Bullseye (11)

Debian Bullseye has the following builds for [`libcrypt1`](https://packages.debian.org/bullseye/libcrypt1):
   1. Build `1:4.4.10-10`
   2. Build `1:4.4.15-1`
   3. Build `1:4.4.16-1`
   4. Build `1:4.4.17-1`
   5. Build `1:4.4.18-1`
   6. Build `1:4.4.18-2`
   7. Build `1:4.4.18-3`
   8. Build `1:4.4.18-4`

You can check the list of builds by [using metasnap](https://metasnap.debian.net/cgi-bin/api?archive=debian&pkg=libcrypt1g&arch=amd64) with

    ../tools/snapshot-dates.py -a debian debian-security -s "bullseye.*" -- libcrypt1

(but the builds `1:4.4.18-1` and `1:4.4.18-3` are missing in the list)

Download and extract the builds using

    ../tools/snapshot-fetch.py -d backtesting/debian/bullseye -x libcrypt1 1:4.4.10-10 1:4.4.15-1 1:4.4.16-1 1:4.4.17-1 1:4.4.18-1 1:4.4.18-2 1:4.4.18-3 1:4.4.18-4

Start the evaluation of the packages with

    ./eval-distribution-package.sh debian bullseye libcrypt1

The summarized results of the test application are stored in `run-summary.txt`.


### Retrieving the packages in Ubuntu

The all official revisions can be found on [Canonical Launchpad](https://launchpad.net/).


#### Focal Fossa (20.04)

Ubuntu Focal has the following builds for [`libcrypt1`](https://packages.ubuntu.com/focal/libcrypt1):
   1. Build `libcrypt1 1:4.4.10-5`
   2. Build `libcrypt1 1:4.4.10-7`
   3. Build `libcrypt1 1:4.4.10-9`
   4. Build `libcrypt1 1:4.4.10-10`
   5. Build `libcrypt1 1:4.4.10-10ubuntu1`
   6. Build `libcrypt1 1:4.4.10-10ubuntu2`
   7. Build `libcrypt1 1:4.4.10-10ubuntu3`
   8. Build `libcrypt1 1:4.4.10-10ubuntu4`
   9. Build `libcrypt1 1:4.4.10-10ubuntu5`

You can check the list of builds on [Launchpad](https://launchpad.net/ubuntu/focal/amd64/libcrypt1) or with

    ../tools/launchpad-dates.py -p release updates security proposed -s focal -- libcrypt1

Download and extract the builds using

    ../tools/launchpad-fetch.sh -V focal -d backtesting/ubuntu/focal/libcrypt1 -x libcrypt1

Start the evaluation of the packages with

    ./eval-distribution-package.sh ubuntu focal libcrypt1

The summarized results of the test application are stored in `run-summary.txt`.


#### Jammy Jellyfish (22.04)

Ubuntu Focal has the following builds for [`libcrypt1`](https://packages.ubuntu.com/jammy/libcrypt1):
   1. Build `4.4.18-4ubuntu1`
   2. Build `4.4.18-4ubuntu2`
   3. Build `1:4.4.26-1`
   4. Build `1:4.4.27-1`
   5. Build `1:4.4.27-1.1`

You can check the list of builds on [Launchpad](https://launchpad.net/ubuntu/jammy/amd64/libcrypt1) or with

    ../tools/launchpad-dates.py -p release updates security proposed -s jammy -- libcrypt1

Download and extract the builds using

    ../tools/launchpad-fetch.sh -V jammy -d backtesting/ubuntu/jammy/libcrypt1 -x libcrypt1

> **Please note:** Jammy packages are compressed using [zstd](https://de.wikipedia.org/wiki/Zstandard), which must be supported by the [Debian package manager (`dpkg`)](https://en.wikipedia.org/wiki/Dpkg). This is the case for Ubuntu Focal and Jammy - please run this command on such a platform (or use a container)

Start the evaluation of the packages with

    ./eval-distribution-package.sh ubuntu jammy libcrypt1

The summarized results of the test application are stored in `run-summary.txt`.

### Summary

By using the files `link.log` and `status.log` in each log folder, we can generate a summary as shown in Table 4:

    ./summary-distribution-package.sh log-{vanilla-test,debian,ubuntu}-*

To verify this table, the Docker output (`out-docker.log`) might be the most human-readable way of the evaluation output.

The script is not able to calculate the values for *unique* releases, this was done manually in Table 4 with the help of `bean-compare`:

    bean-compare -v -l libcrypt.so.1 -r -d -N backtesting/ubuntu/focal/libcrypt1

would output

| 1:4.4.10-5 | 1:4.4.10-7 | 1:4.4.10-9 | 1:4.4.10-10 | 1:4.4.10-10ubuntu1 | 1:4.4.10-10ubuntu2 | 1:4.4.10-10ubuntu3 | 1:4.4.10-10ubuntu4 | 1:4.4.10-10ubuntu5 |
|------------|------------|------------|-------------|--------------------|--------------------|--------------------|--------------------|--------------------|
| *(update)* | *update*   | *update*   | *update*    | *update*           | *update*           | *update*           | *update*           | *update*           |
|            | .build-id  |            |             | .build-id          | .build-id          |                    | .build-id          |                    |


which indicates, that Ubuntu Focal has no changes in relevant code or data sections. Sometimes even the Build ID does not change.
Hence, we have no *unique* versions to test for updates in this distribution/version.


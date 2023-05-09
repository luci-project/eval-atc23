
Expat Test
==========

The XML parser library [Expat](https://libexpat.github.io/) is the primary evaluation target since it meets several criteria:

 * [popular](https://qa.debian.org/popcon.php?package=expat) and widely used: ranked #51 of [most installed debian packages](https://popcon.debian.org/by_inst)
 * [frequent releases](https://github.com/libexpat/libexpat/releases) allowing good testing
 * several [vulnerabilities](https://www.cvedetails.com/product/39003/Libexpat-Project-Libexpat.html?vendor_id=16735) emphasizing relevance for live-patching
 * extensive (official) [test suite](https://github.com/libexpat/libexpat/tree/master/expat/tests)

We evaluate *Luci* with the test suite using custom (vanilla) library builds and the corresponding packages distributed by Debian and Ubuntu.

> **Please note:** Expat builds two shared libraries, which only differ in the encoding they support: `libexpat.so` for UTF-8 and `libexpatw.so` using `wchar_t` for UTF-16. Since they are rather identical when it comes to functionality, we only focus on the first version in the tests.


Preparation
-----------

We strongly recommend using a standard installation of *Ubuntu Focal* (due to the compatibility with Ubuntu's package compression method) with no modifications regarding the system configuration for the artifact evaluation.

[Docker Engine](https://docs.docker.com/engine/install/ubuntu/) is required for building and testing (using the [official Debian Bullseye Docker image](https://hub.docker.com/_/debian)).

You have to setup the environment by building and installing *Luci* and its submodules:

    ../setup.sh

In case you have already performed evaluation runs and want to start over again, you can remove its artifacts from this directory by executing

    ./cleanup.sh

The following documentation contains a detailed description of the steps to reproduce the Expat artifacts of the paper.

However, all steps described bellow can also be automatically executed with

    ./run.sh

In the end, the results of all individual tests (baseline, vanilla, and backtesting) are stored in a `result-DATE` directory.

> **Please note:** The *failed test cases* in the `run-` output files do not refer to issues with *Luci* but to bugs in older libraries and, hence, are expected.
> These *failed test cases* can be seen in the baseline as well and, when using dynamic updates via *Luci*. These failed tests reduce with increasing library version.

Files prefixed with `tableX` correspond to table *X* in the paper.
However, a single table in the paper may be based on multiple such files (see detailed description for further information).

> **Please note:** The summary files (`run-summary.txt`, `table*-run-*.txt`) are aggregated using the output of the test application and (in case of backtesting) other log files to match the package names (even when version numbers are identical).
> However, it is possible that the script producing this file has bugs (especially in corner cases), therefore if in doubt please check the actual log files `run-*.out` (output of a single test application process), `link.log` (changes of library symlink by the observer script), and `status.log` (link status output of *Luci*).


Vanilla Build
-------------

Testing a range of official releases.

### Build Libraries

The build process is performed in a fresh environment using the [official Debian Bullseye Docker image](https://hub.docker.com/_/debian) and installing the necessary build utilities

    apt-get install -y git gcc cmake automake libtool gettext docbook2x

Libraries are built from the official [repository](https://github.com/libexpat/libexpat/) using *Autotools* as suggested by the library authors.
For more recent versions, this is encapsulated in the `buildconf.sh`, while older releases require manual executing

    aclocal
    autoheader
    autoconf

For `configure`, only the `--prefix` parameter (to adjust the install directory) will be set.

To speed up build several releases, we can avoid restarting the container (retrieving the repository & installing build utils) by using a separate build directory, which gets deleted after finishing the build.
This prevents the build system from using artifacts of previous builds.

The whole process is automated in `gen-lib.sh`, which takes the git tags of releases to build as parameter.
For the evaluation, all releases of version 2 (2.0.0 - 2.5.0) are taken into account:

    ./gen-lib.sh R_2_{0,1}_{0,1} R_2_2_{0..10} R_2_3_0 R_2_4_{0..9} R_2_5_0

This will create folders with the git commit hash (40 character long hex value) as name.
For convenience, the folder `release/` contains symbolic links with the git tag names to the corresponding library folder.

The top of Table 1 can now be generated using

    bean-compare -vv -l libexpat.so.1 -r -d -s release -o table1-compatibility-vanilla-with-dwarf.htm

which will analyze the shared objects in the folders and decide if the libraries are eligible for subsequent dynamic updates.

> **Please note:** If your terminal width is not wide enough or the colors are confusing, you can view `table1-compatibility-vanilla-with-dwarf.htm` in your web browser instead.

The versions of the shared library are listed in ascending order, each version having its own column and highlighting (bright color on dark terminal themes) changes to the previous one.
Names in bold font correspond to sections in which changes cause incompatibilities and preventing an update (hence requiring a restart of the application).

Since debug symbols are included in the shared libraries, the `.debug` section corresponds to `DWARF` in Table 1, with the hashes for
  * `RW`: *writeable vars*
  * `dt`: *internal types*
  * `fn`: *external API*

If you want to omit the DWARF debug symbols, exchange Parameter `-s` with `-N`:

    bean-compare -vv -l libexpat.so.1 -r -d -N release -o table1-compatibility-vanilla-elf-only.htm

In this output, the row `.debug *` corresponds to
  * `RW`: hash of `data` (not in Table)
  * `fn`: `symtab` in ELF section


#### Bug in R_2_1_0 preventing build

The release 2.1.0 will abort build due to a missing call to `automake`, see commit [426bb86](https://github.com/libexpat/libexpat/commit/426bb860ccf225bff11be79e15c03cba1f8058fb).
Hence, `gen-lib.sh` will execute

    automake --add-missing 2>/dev/null || true

before calling `./configure`


### Build Test Suite

Since the Expat team maintains an [exemplary test suite](https://github.com/libexpat/libexpat/tree/master/expat/tests) (which is extended with each new release) with a good code overage, its [latest version is the starting point](https://github.com/libexpat/libexpat/tree/R_2_5_0/expat/tests).

However, we had to perform certain adjustments:
 * we have extracted certain internal dependencies (`ascii.h`, `internal.h` and `siphash.h` from the library folder, functions `unsignedCharToPrintable` from `xmlparse.c` and `_INTERNAL_trim_to_complete_utf8_characters` from `xmltok.c` into `internal.c`)
 * since certain tests will cause serious issues like `segfault` on older releases, we query the library version (provided by the API) and only execute the following test cases if the criteria is met:
   - `test_set_foreign_dtd` if version >= 2.1.0 (newly introduced in API)
   - `test_foreign_dtd_with_doctype` if version >= 2.1.0 (newly introduced in API)
   - `test_invalid_tag_in_dtd` if version >= 2.2.1 (else endless loop)
   - `test_hash_collision` if version >= 2.1.0 (newly introduced in API)
   - `test_missing_encoding_conversion_fn` if version >= 2.2.3 (else segmentation fault)
   - `test_misc_attribute_leak` if version >= 2.2.1 (else segmentation fault on subsequent runs) 
   - `test_alloc_dtd_copy_default_atts` if version >= 2.2.1 (else double free)
   - `test_alloc_external_entity` if version >= 2.2.1 (else double free)
   - `test_alloc_reset_after_external_entity_parser_create_fail` if version >= 2.5.0 (else double free)
   - `test_nsalloc_long_uri` if version >= 2.1.1 (else segmentation fault)
   - `test_nsalloc_long_attr` if version >= 2.1.1 (else segmentation fault)
   - `test_nsalloc_long_attr_prefix` if version >= 2.1.1 (else segmentation fault)
   - `test_nsalloc_long_element` if version >= 2.1.1 (else segmentation fault)
   - `test_nsalloc_long_context` if version >= 2.2.1 (else double free)
   - `test_nsalloc_long_default_in_ext` if version >= 2.2.1 (else double free)
   - `test_nsalloc_prefixed_element` if version >= 2.2.1 (else double free)
 * excluding test `test_accounting_precision` since it relies on internal functions 
 * excluding test `test_misc_version` checking the version (which would always fail except with the library it was built with)
 * executing the original contents of the `main`-body in an endless loop (instead of a single execution) while measuring the runtime - so the effect of dynamic updates can become visible.

Hence the number of total test cases depend on the library version, ranging from 326 to 343.

The sources for the modified test suite are located in the `src-test` directory.

The script `gen-test.sh` builds the test suite within a Debian Bullseye Docker image, using the official repository for includes and a previously build library (e.g., version 2.4.0) to link against:

    ./gen-test.sh R_2_4_0

After completion, the resulting test binary is stored in `test/runtests`.


### Measure Baseline

For every library version, we start the test application using the system's default RTLD, which dynamically links it against the corresponding shared library build, and kill it after approx. 25 seconds, continuing with the next version.

The `run-baseline.sh` script performs this inside a Docker container with a Debian Bullseye image.
It is called by

    ./eval-vanilla.sh baseline 2.0.0 2.5.0

and stores the artifacts (logs) in a directory with the format `log-vanilla-baseline-DATE-TIME`:
The output of the test application `run-*.log` contains the results for the baseline measurement.
The summarized results in `run-summary.txt` correspond to the bottom part of Table 1 in the paper.


### Dynamic Updates with Luci

Since DWARF debug information should be considered, we first start the `bean-elfvarsd` service (hashing information from the debug symbols) which listens on a local TCP port (9001) for queries from *Luci*.
The tests itself are performed inside a Docker container with a Debian Bullseye image:

Initially, a symbolic link to the first version of the library.
The interpreter of the test application is modified to start with *Luci* instead of the system RTLD (using `elfo-setinterp`).

*Luci*'s configuration is stored in environmental variables:
 * dynamic updates are enabled
 * detection of outdated code (using *userfaultfd*) is enabled
 * debug output stored to `luci.log`
 * status info with information about succesfull and rejected dynamic updates are stored in a `status,info` file
 * connection information for `bean-elfvarsd` service is set

Then the test application is executed.
After a certain time, the symbolic link is modified to point to the subsequent version of the library (and noted with timestamp in `link.log`).

*Luci* should now detect the change (employing *inotify*), check the compatibility (including quering `bean-elfvarsd`), and then either perform the update to the new version or discard it and continue the test application with the previous version.
In either case, it writes to `status.info` (`SUCCESS` or `FAILED`).

The control script `run-test.sh` will check this status file after a few seconds:
If it detects a failure, it will kill the test application and restart it - which will dynamically link it with the current version.
This causes the `run`-logfile to rotate.

In any case, the control script will continue after a certain amount of time with the next library version and repeat the steps, until all versions have been checked.

To start the described testing setup, run

    ./eval-vanilla.sh test 2.0.0 2.5.0

The artifacts (logs) are stored in a directory with the format `log-vanilla-test-DATE-TIME`:

As the baseline test, the output of the test application `run-*.log` contains the results for the baseline measurement, the summarized results in `run-summary.txt` correspond to the middle part of Table 1.


Backtesting Distribution Packages
---------------------------------

The previously generated test application is dynamically linked against official *libexpat* packages in [Debian](https://www.debian.org/) ([Buster](https://www.debian.org/releases/buster/) & [Bullseye](https://www.debian.org/releases/bullseye/)), and [Ubuntu](https://ubuntu.com/) ([Focal](https://releases.ubuntu.com/focal/) & [Jammy](https://releases.ubuntu.com/jammy/)).

For each release of a distribution, we test all published builds (during development phase and after stable release) by starting with the first build and replacing it with the subsequent builds after a certain time.
If an update cannot be applied, the test application is restarted, dynamically linked against the build causing the incompatibility and the replacement starts again.

But before starting the test, we have to retrieve the all published builds from the official archives and extract them.

> **Please note:** Since the scripts employ the [Debian package manager](https://en.wikipedia.org/wiki/Dpkg) for extracting the contents of each package, this should run on a debianoid distribution. We recommend Ubuntu Focal due to the compatibility.

> **Please note:** Since we are not able to retrieve debug symbols for each build (they are sometimes missing in the archives, backtesting does not use DWARF hashing and work on the binaries only.


### Retrieving the packages in Debian

With the help of the [metasnap.debian.net](https://metasnap.debian.net/) we are able to determine the date a certain version was published, and using this information in conjunction with the [snapshot.debian.org](https://snapshot.debian.org/) service, we are able to download old revisions of an official package.

> **Please note:** The snapshot service has a [not so well-documented rate limit](https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=977653) for its service. We therefore strongly recommend to download the packages only once. If you encounter a rate limit, please try again after a certain time.

#### Buster (10)

Debian Buster has following builds for [`libexpat1`](https://packages.debian.org/buster/libexpat1):
   1. Build `2.2.0-2`
   2. Build `2.2.1-1`
   3. Build `2.2.1-2`
   4. Build `2.2.1-3`
   5. Build `2.2.2-1`
   6. Build `2.2.2-2`
   7. Build `2.2.3-1`
   8. Build `2.2.3-2`
   9. Build `2.2.5-1`
   10. Build `2.2.5-2`
   11. Build `2.2.5-3`
   12. Build `2.2.6-1`
   13. Build `2.2.6-2` **(Buster stable release)**
   14. Build `2.2.6-2+deb10u1`
   15. Build `2.2.6-2+deb10u2`
   16. Build `2.2.6-2+deb10u3`
   17. Build `2.2.6-2+deb10u4`
   18. Build `2.2.6-2+deb10u5`
   19. Build `2.2.6-2+deb10u6`

You can check the list of builds by [using metasnap](https://metasnap.debian.net/cgi-bin/api?archive=debian&pkg=libexpat1&arch=amd64) with

   ../tools/snapshot-dates.py -a debian debian-security -s "buster.*" -- libexpat1 | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq

However, two builds (`2.2.5-1` and `2.2.5-2`) are not included in the output because they did not appear in the suite `buster` but only `sid`/`unstable` since they have been replaced shortly after by the subsequent version.

Download and extract the builds using

    ../tools/snapshot-fetch.py -d backtesting/debian/buster libexpat1 2.2.0-2 2.2.1-{1,2,3} 2.2.2-{1,2} 2.2.3-{1,2} 2.2.5-{1,2,3} 2.2.6-{1,2} 2.2.6-2+deb10u{1,2,3,4,5,6} -x

To analyze the differences between the builds (first top-half *Binary releases in Debian Buster* of Table 2 in paper) run

    bean-compare -v -r -d -N backtesting/debian/buster/libexpat1 -o table2-debian-buster-elf-section.htm

(`debug *` refers to the symbol table only, since no debug symbols / DWARF data is available)

Start the evaluation of the packages with

    ./eval-distribution-package.sh debian buster libexpat1

The summarized results of the test applications output in `run-summary.txt` correspond to the first bottom-half of Table 2.


#### Bullseye (11)

Debian Bullseye has following builds for [`libexpat1`](https://packages.debian.org/bullseye/libexpat1):
   1. Build `2.2.6-2` **(development start using Buster stable release)**
   2. Build `2.2.7-1`
   3. Build `2.2.7-2`
   4. Build `2.2.9-1`
   5. Build `2.2.10-1`
   6. Build `2.2.10-2` **(Bullseye stable release)**
   7. Build `2.2.10-2+deb11u1`
   8. Build `2.2.10-2+deb11u2`
   9. Build `2.2.10-2+deb11u3`
   10. Build `2.2.10-2+deb11u4`
   11. Build `2.2.10-2+deb11u5`

You can check the list of builds by [using metasnap](https://metasnap.debian.net/cgi-bin/api?archive=debian&pkg=libexpat1&arch=amd64) with

    ../tools/snapshot-dates.py -a debian debian-security -s "bullseye.*" -- libexpat1 | sed -e 's/^.* \([^ ]*\)$/\1/' | uniq

Download and extract the builds using

    ../tools/snapshot-fetch.py -d backtesting/debian/bullseye/ libexpat1 2.2.6-2 2.2.7-{1,2} 2.2.9-1 2.2.10-{1,2} 2.2.10-2+deb11u{1,2,3,4,5} -x

To analyze the differences between the builds (second top-half *Debian Bullseye* of Table 2 in paper) run

    bean-compare -v -r -d -N backtesting/debian/bullseye/libexpat1 -o table2-debian-bullseye-elf-section.htm

(`debug *` refers to the symbol table only, since no debug symbols / DWARF data is available)

Start the evaluation of the packages with

    ./eval-distribution-package.sh debian bullseye libexpat1

The summarized results of the test applications output in `run-summary.txt` correspond to the last bottom-half of Table 2.


### Retrieving the packages in Ubuntu

The all official revisions can be found on [Canonical Launchpad](https://launchpad.net/).

#### Focal Fossa (20.04)

Ubuntu Focal has following builds for [`libexpat1`](https://packages.ubuntu.com/focal/libexpat1):
   1. Build `2.2.7-2`
   2. Build `2.2.9-1build1`
   3. Build `2.2.9-1`
   4. Build `2.2.9-1ubuntu0.2`
   5. Build `2.2.9-1ubuntu0.4`
   6. Build `2.2.9-1ubuntu0.5`
   7. Build `2.2.9-1ubuntu0.6`

You can check the list of builds on [Launchpad](https://launchpad.net/ubuntu/focal/amd64/libexpat1) or with

    ../tools/launchpad-dates.py -p release updates security proposed -s focal -- libexpat1 | sed -e 's/^.* \([^ ]*\)$/\1/' | sort -u

Download and extract the builds using

    ../tools/launchpad-fetch.sh -V focal -d packages/ubuntu-focal -x libexpat1

Start the evaluation of the packages with

    ./eval-distribution-package.sh ubuntu focal libexpat1

The results are saved in the same format as the previous reports.


#### Jammy Jellyfish (22.04)

Ubuntu Focal has following builds for [`libexpat1`](https://packages.ubuntu.com/jammy/libexpat1):
   1. Build `2.4.1-2`
   2. Build `2.4.1-3`
   3. Build `2.4.2-1`
   4. Build `2.4.3-1`
   5. Build `2.4.3-2`
   6. Build `2.4.3-3`
   7. Build `2.4.4-1`
   8. Build `2.4.5-1`
   9. Build `2.4.5-2`
   10. Build `2.4.6-1`
   11. Build `2.4.7-1`
   12. Build `2.4.7-1ubuntu0.1`
   13. Build `2.4.7-1ubuntu0.2`

You can check the list of builds on [Launchpad](https://launchpad.net/ubuntu/jammy/amd64/libexpat1) or with

    ../tools/launchpad-dates.py -p release updates security proposed -s jammy -- libexpat1 | sed -e 's/^.* \([^ ]*\)$/\1/' | sort -u

Download and extract the builds using

    ../tools/launchpad-fetch.sh -V jammy -d backtesting/ubuntu/jammy/libexpat1 -x libexpat1

> **Please note:** Jammy packages are compressed using [zstd](https://de.wikipedia.org/wiki/Zstandard), which must be supported by the [Debian package manager (`dpkg`)](https://en.wikipedia.org/wiki/Dpkg). This is the case for Ubuntu Focal and Jammy - please run this command on such a platform (or use a container)

Start the evaluation of the packages with

    ./eval-distribution-package.sh ubuntu focal libexpat1

The results are saved in the same format as the previous reports.


### Summary

By using the files `link.log` and `status.log` in each log folder, we can generate a summary as shown in Table 3:

    ./summary-distribution-package.sh log-{vanilla-test,debian,ubuntu}-*

To verify this table, the Docker output (`out-docker.log`) might be the most human readable way of the evaluation output.

(The script is not able to calculate the values for *stable* releases, this was done manually in Table 3)

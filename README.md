Luci Artifacts
==============

Preface
-------

The dynamic linker/loader consists of the following parts:

  * [DLH](https://gitlab.cs.fau.de/luci-project/dlh) provides basic functionality similar to libc/STL for creating static freestanding applications (without *glibc*)
  * [Elfo](https://gitlab.cs.fau.de/luci-project/elfo) is lightweight parser for the [Executable and Linking Format](https://de.wikipedia.org/wiki/Executable_and_Linking_Format), supporting common GNU/Linux extensions
  * [Bean](https://gitlab.cs.fau.de/luci-project/bean) — binary explorer/analyzer to compare shared libraries and detect changes
  * [Luci](](https://gitlab.cs.fau.de/luci-project/luci), the actual dynamic linker/loader with DSU capabilities and *glibc* compatibility (`ld-linux-x86-64`), employing the beforementioned tools.

This [artifact evaluation repository](https://gitlab.cs.fau.de/luci-project/eval-atc23) contains the *Luci* and scripts to perform the evaluation.

These Git repositorities are hosted in a [public project](https://gitlab.cs.fau.de/luci-project) on a GitLab instance of [Friedrich-Alexander-Universität Erlangen-Nürnberg (FAU)](https://www.fau.eu/) with an automatic mirror on [GitHub](https://github.com/luci-project).

Further dependencies are the official repositorities of

  * [Capstone (on Github)](https://github.com/capstone-engine/capstone/)
  * [Expat (on GitHub)](https://github.com/libexpat/libexpat.git)
  * [libxcrypt (on GitHub)](https://github.com/besser82/libxcrypt)
  * [OpenSSL (at git.openssl.org)](git://git.openssl.org/openssl.git)
  * [WolfSSL (on GitHub)](https://github.com/wolfSSL/wolfssl.git)
  * [Zlib (on GitHub)](https://github.com/madler/zlib.git)

For the evaluation, Packages for Debian and Ubuntu from [Canonical Launchpad](https://launchpad.net/), Debian [Snapshot](https://snapshot.debian.org/) and [Metasnap](https://metasnap.debian.net/) are used.
Building and testing is performed inside a Docker container using [official Debian images](https://hub.docker.com/_/debian).

We strongly recommend using a freshly installed *Ubuntu Focal Fossa (20.04)* for evaluation to circumvent side effects (due to certain customizations of the system configuration).

### Local Install

Make sure that you meet the requirements (e.g., [Docker engine](https://docs.docker.com/engine/install/) installed) — for a new *Ubuntu Focal* installation execute

    sudo apt-get update
    sudo apt-get install -y apt-transport-https build-essential ca-certificates clang curl file fpc g++ gcc gccgo gfortran git gnat gnupg golang less libcap2-bin libstdc++-10-dev make rustc
    curl -fsSL https://get.docker.com | sudo sh
    sudo usermod -aG docker $USER
    sudo reboot

Recursively clone this repository (the path must not contain spaces or special characters) and run the setup script.

    git clone --recursive https://gitlab.cs.fau.de/luci-project/eval-atc23.git
    cd eval-atc23
    ./setup.sh

This will create the directory `/opt/luci` (using `sudo`, changing ownership to current user) and install the *Luci* runtime into according to its [build instructions](https://gitlab.cs.fau.de/luci-project/luci#build).

### Virtual Machine

A preconfigured Ubuntu Focal VM image for [VirtualBox 7](https://www.virtualbox.org/) is available at <URL>:
Its VM user is `user` and password `pass`, the required utilities for building and testing are installed.
This repository is cloned to `/home/user/eval` (run `/home/user/eval/update.sh` to pull the `master` branch).


Getting started
---------------

Either start the VM or install locally (as described above) and switch with a terminal into this repositorities, then run

    ./luci/example/demo.sh

for a ~1 minute demonstration of an application employing a library to calculate Fibonacci sequence numbers — while every 10 seconds the library gets exchanged with another version using an different algorithm.
Neither source nor build script in [`luci/example`](https://gitlab.cs.fau.de/luci-project/luci/-/tree/master/example) have adjustments for dynamic software updates.
See the [documentation](https://gitlab.cs.fau.de/luci-project/luci/-/blob/master/example/README.md) for further details about the example.

You can also check out the included [test cases](https://gitlab.cs.fau.de/luci-project/luci#test-cases):

    # Build and run a simple test case with two dynamic updates
    ./luci/test/run.sh -u -o 2-simple
    # Build a similar test cases with clang updating libraries loaded via dlopen
    ./luci/test/run.sh -u -c LLVM -o -v 5 2-dlopen-dynamic
    # Build and test dynamic updates in Fedora (using the official Docker image)
    ./luci/tools/docker.sh fedora:37 ./test/run.sh -u 2-simple-fork
    # Build and run Ada, Fortran, Go, Pascal and Rust test cases with dynamic updates
    ./luci/test/run.sh -u -g lang


Detailed Instructions
---------------------

For the evaluation, several versions of the shared libraries

  * Expat
  * libxcrypt
  * Zlib

are dynamically updated in the test applications (based on unit tests).


Testing **vanilla** versions (unmodified, from the official source) of libraries:

1. Build multiple versions of the shared library (`gen-lib.sh`)
  * In a clean environment (Docker with an official base image), installing only the required dependencies
  * Retrieving the source from the official repository
  * For each version of the shared library:
    - Checkout of the corresponding commit
    - Configuration using default flags
    - In case that the version is known to be buggy or are not supported with current compilers, apply adjustments
    - Build the shared library
    - Install to a directory exclusive for this version (labeled with the commit hash and mounted from the host)
    - Clean up -- a subsequent build must not use any artifacts from a previous build
  * Update compatibility of the versions can be checked using `bean-compare`
2. Build test application (`gen-test.sh`)
  * Based on unit test or similar from the official project
  * But removing all tests which are not solely based on the shared library, use version dependend interna (structure sizes) or will cause serious issues on earlier releases (Segmentation faults oder serious memory leaks)
  * Linked against a recent version of the shared library created in the previous step
3. Testing baseline (`run-baseline.sh`)
  * Control script is starts in a containerized enivronment (Docker with an official base image)
  * For each version of the shared library:
    - Generic shared library symlink points to the current version
    - Start test application as background process
    - Capture output in log files (see below)
    - After several seconds, kill the background process
  * Processing/summarizing output
4. Testing dynamic updates (`run-test.sh`)
   * On the host, a service for hashing DWARF data (`bean-elfvarsd`) starts
   * Starting Control script in a containerized enivronment (Docker with an official base image)
   * Setting up *Luci* in the container
   * Generic shared library symlink points to the first version
   * Starting test application (with *Luci*) as background process
   * For each version of the shared library:
     - After several seconds change symbolic link for the shared library to the next version , the symbolic link to the library is changed to the next version
     - Check the process, especially the status interface (`LD_STATUS_INFO`): if *Luci* was not able to perform the update, e.g., due to incompatiblity (*Luci* sent **FAILED** -- the application is still running with the old version), the test application gets stopped and restarted (hence nowusing the current version)
  * Processing/summarizing output
   * All logs are stored in a separete directory for each test (`log-vanilla` with a date/time suffix):
     - `elfvarsd.{log,err}` is the output of the DWARF hashing daemon
     - `link.log` lists the changes of the symbol links for the shared library
     - `luci.log` is the debug output of *Luci* (appended on each restart)
     - `status.log` contains *Luci*s library information
     - standard output and error are stored for each start of the test application (`run-yyyy-mm-dd_HH:MM.{log,err}`)
     - `run-summarize.txt` is the processed form of the test application output
     - `out-docker.log` contains the standard output of docker (as seen on the terminal)
     - `out.log` is the standard output generated on the host only (`elfvarsd`)

The last two steps are wrapped into `eval-vanilla.sh` resolving version tags to commit hashes.


For **backtesting** we have to perform the following steps for each distribution/version:

1. Retrieve multiple releases of the official packages
   * For each releasd:
     - Find and download via [Canonical Launchpad](https://launchpad.net/) (`launchpad-fetch.sh `) and Debian [Snapshot](https://snapshot.debian.org/) (`snapshot-fetch.py`)
     - Extract package
     - Adjust directory structure (in case there where changes)
   * Update compatibility of the versions can be checked using `bean-compare`
2. Testing dynamic updates (reuse `run-test.sh`)
   * Ignore debug symbols since there is no reliable way to retrieve the debug packages from the archive
   * Starting Control script in a containerized enivronment (Docker with an official base image)
   * Setting up *Luci* in the container
   * Generic shared library symlink points to the first version
   * Starting test application from vanilla build (with *Luci*) as background process
   * For each release of the shared library:
     - After several seconds change symbolic link for the shared library to the next version , the symbolic link to the library is changed to the next version
     - Check the process, especially the status interface (`LD_STATUS_INFO`): if *Luci* was not able to perform the update the test application gets stopped and restarted
   * Processing/summarizing output
   * All logs are stored in a separete directory for each test (`log-DISTRIBUTION` with a date/time suffix)

For the last step the wrapper script `eval-distribution-package.sh` is provided.

After all tests have been executed, the script `summary-distribution-package.sh` can generate a short overview like presented in the paper.

Since the execution of the individual steps take a noticable amount of time, the different evaluation targets contain the script `run.sh` which sequentially performs all steps described above.
Results are placed in `result-DATE` folder.
If certain files are relevant for Tables provided in the paper, they are prefixed with `table`.

However, you can still manually execute the steps (useful if you just want to repeat a specific step again), the `README.md` in the corresponding folder give further specific details.


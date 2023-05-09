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

Make sure that you meet the requirements (e.g., [Docker engine](https://docs.docker.com/engine/install/) installed).
Recursively clone this repository (the path must not contain spaces or special characters) and run the setup script.

    git clone --recursive https://gitlab.cs.fau.de/luci-project/eval-atc23.git
    cd eval-atc23
    ./setup.sh

This will create the directory `/opt/luci` (using `sudo`, changing ownership to current user) and install the *Luci* runtime into according to its [build instructions](https://gitlab.cs.fau.de/luci-project/luci#build).

### Virtual Machine

A preconfigured Ubuntu Focal VM image for [VirtualBox 7](https://www.virtualbox.org/) is available at <URL>:
Its VM user is `user` and password `pass`, the required utilities for building and testing are installed.
This repository is cloned to `/home/user/eval` (run `/home/user/eval/update.sh` to pull the `master` branch).

In addition, this image also contains the `.deb.` package files for Debian and Ubuntu (to prevent issues due to rate limits) — however, the utils to automaticall download them from the official sources are included, so you can verify the integrity.


Getting started
---------------

Either start the VM or install locally (as described above) and switch with a terminal into this repositorities, then run

    luci/example/demo.sh

for a ~1 minute demonstration of an application employing a library to calculate Fibonacci sequence numbers — while every 10 seconds the library gets exchanged with another version using an different algorithm.
Neither source nor build script in [`luci/example`](luci/example) have adjustments for dynamic software updates.
See the [enclosed documentation](luci/example/README.md) for further details about the example.


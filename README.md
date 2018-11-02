## qwerty.sh: download, verify, and unpack files in a single command.

[qwerty.sh](https://qwerty.sh) is a script as a service.

Contents:

* [Manage the Unmanaged](#manage-the-unmanaged)
* [Use Cases](#use-cases)
* [Usage](#usage)
* [Dependencies](#dependencies)
* [Using a Checksum](#using-a-checksum)
* [Trust](#trust)
* [The qwerty.sh Web Service](#the-qwertysh-web-service)
* [Motivation](#motivation)
* [Why "qwerty.sh"?](#why-qwertysh)
* [Meta](#meta)


### Manage the Unmanaged

It is a solved (or solvable) problem to download, verify, and unpack files as a
programmer with most operating systems and programming languages. Everything
else is undefined. Use qwerty.sh to download, verify, and unpack: unversioned
files, specific versions of development tools, and project data.

Know that you have a bad download at **download time** and not _run time_.


### Use Cases

Use qwerty.sh when bootstrapping builds and development environments, for:

1. Repeatable single-command downloads in build systems & Dockerfile workflows.
2. Trusted copy/paste developer tool instructions (replacing `curl ... | sh`).
3. An easy-to-type command to bootstrap a development environment.


### Usage

Arguments start after `sh -s -`. The `--help` flag shows full usage.

```sh
curl -sSL qwerty.sh | sh -s - --help
curl -sSL qwerty.sh/v0.3.5 | sh -s - --help
```

See full examples below.


### Dependencies

* `curl`, to fetch the qwerty.sh script and have it download target files.
* `sh`, which is a given on all Unix-like systems, to run the qwerty.sh script.
* `openssl` command, which is widely available with curl, to verify checksums.

The qwerty.sh project provides fully portable shell using commands commonly
found on Unix platforms, and makes every effort to provide a simple, clear
error message in the event that a dependency is missing.


### Using a Checksum

Download a shell script, verify it, execute it (without keeping it):

```sh
curl -sSL qwerty.sh |\
  sh -s - \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  http://hello.qwerty.sh | sh
```

Download a program, verify it, keep it, make it executable:

```sh
curl -sSL qwerty.sh |\
  sh -s - \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  --output=hello --chmod=a+x \
  http://hello.qwerty.sh
```

Download an archive, verify it, unpack it (without keeping the archive itself):

```sh
curl -sSL qwerty.sh |\
  sh -s - \
  --sha256=70c98b2d0640b2b73c9d8adb4df63bcb62bad34b788fe46d1634b6cf87dc99a4 \
  http://download.redis.io/releases/redis-5.0.0.tar.gz |\
  tar -xvzf -
```


### Trust

The qwerty.sh project has a single focus: provide a script as a service.

The script downloads and runs locally; no information given to the script is
provided to the qwerty.sh server. When running qwerty.sh, only the `curl`
portion of the command line is known to the qwerty.sh server, which only
indicates a request to download the qwerty.sh script.

The qwerty.sh script is provided over HTTPS which is encrypted by [Let's
Encrypt](https://letsencrypt.org/). This encryption initiates a web of trust:

* Determine details (e.g. a checksum) which validate a given file.
* Get the qwerty.sh script, knowing that it transmitted through HTTPS.
* Tell the qwerty.sh script known details about the target file to download.

qwerty.sh is available as specific versions to further guarantee repeatability.

[BSD 2-Clause License](LICENSE)


### The qwerty.sh Web Service

See: [web/README.md](web/README.md#readme)


### Motivation

How do you verify integrity of a downloaded file, when the download installs
the very tool that you need to run the build process? Too often, you do
not. Installation instructions commonly pipe the output of `curl` into `sh`,
sometimes leading to blind `sudo` password prompts (!), and archive files often
download over plaintext internet connections without a checksum or signature.

Until it is trivial to download, verify, and unpack files _from anywhere_,
developers and builds will skip (or not even consider!) the verification
step. Verification is about trust and repeatability; the only way to know that
you downloaded what you expected is to know up front what you are expecting.


### Why "qwerty.sh"?

Bootstrap a repeatable build on a Unix-like system with just one dependency:
a keyboard.


### Meta

Contact: community@qwerty.sh

Status: Beta, with a clear path toward a fully production-ready v1.0 release.

Copyright (c) 2018, Ron DuPlain. All rights reserved.
BSD 2-Clause License.

... with apologies to Dvorak.

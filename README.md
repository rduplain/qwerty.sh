## qwerty.sh: download, verify, unpack files in a single, portable command.

[qwerty.sh](https://qwerty.sh) is a script as a service to download, verify,
and unpack files in a single, portable command.

On any Unix shell with `curl` available:

```sh
QWERTY_SH=https://raw.githubusercontent.com/rduplain/qwerty.sh/v0.7/qwerty.sh
alias curl-https="curl --proto '=https' --tlsv1.2 -sSf"  # Accept no less.
alias qwerty.sh="curl-https $QWERTY_SH | sh -s -"
```

Execute [a file][hello.sh] downloaded with `git`:

```sh
qwerty.sh https://github.com/rduplain/qwerty.sh.git web/hello/hello.sh:- | sh
```

Execute [a file][hello.sh], but only if it matches a predetermined checksum:

```sh
qwerty.sh \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  http://hello.qwerty.sh | sh
```

`qwerty.sh` works without any installation, using whatever `curl`, `git`, and
`openssl` commands it finds.

Contents:

* [Manage the Unmanaged](#manage-the-unmanaged)
* [Use Cases](#use-cases)
* [Usage](#usage)
* [Dependencies](#dependencies)
* [Using a Checksum](#using-a-checksum)
* [Using git](#using-git)
* [Using a Run-Command (rc) File](#using-a-run-command-rc-file)
* [Conditional Execution](#conditional-execution)
* [Conditional Execution, Full Example](#conditional-execution-full-example)
* [Event Hooks](#event-hooks)
* [Trust](#trust)
* [The qwerty.sh Web Service](#the-qwertysh-web-service)
* [Motivation](#motivation)
* [Why "qwerty.sh"?](#why-qwertysh)
* [White Label](#white-label)
* [Alternative Hosting and Local Usage](#alternative-hosting-and-local-usage)
* [Meta](#meta)


### Manage the Unmanaged

It is a solved (or solvable) problem to download, verify, and unpack files
working with the tools provided with a programming language. Everything else is
undefined. Use qwerty.sh to download, verify, and unpack: unversioned files,
specific versions of development tools, and project data.

More broadly, download any file and make it part of a project without checking
it into the repository. Add individual files from other git repos. Outside of
git, determine the file's checksum and have qwerty.sh verify it. The qwerty.sh
commands get checked into the project repo; the resulting files do not.

Know that you have a bad download at **download time** and not _run time_,
especially to save from troubleshooting hidden errors or running untrusted
code.


### Use Cases

Use qwerty.sh when bootstrapping builds and development environments, for:

1. Repeatable single-command downloads in build systems & Dockerfile workflows.
2. Trusted copy/paste developer tool instructions (replacing `curl ... | sh`).
3. An easy-to-type command to bootstrap a development environment.


### Usage

Arguments start after `sh -s -`. The `--help` flag shows full usage.

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh        | sh -s - --help
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh/v0.6.3 | sh -s - --help
```

See full examples below.


### Dependencies

* `curl`, to fetch the qwerty.sh script and have it download target files.
* `sh`, which is a given on all Unix-like systems, to run the qwerty.sh script.
* `openssl`, which is widely available with curl, to verify checksums.
* `git`, a version control system, to verify file integrity.

Arguments to qwerty.sh indicate whether to use a checksum or use git to verify
files, and qwerty.sh requires `openssl` or `git` accordingly. For HTTPS, `curl`
must support TLSv1.2 (2008), which it commonly does.

The qwerty.sh project provides fully portable shell using commands commonly
found on Unix platforms, and makes every effort to provide a simple, clear
error message in the event that a dependency is missing.


### Using a Checksum

Download a shell script, verify it, execute it (without keeping it):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  http://hello.qwerty.sh | sh
```

Download a program, verify it, keep it, make it executable (then execute it):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  --output=hello --chmod=a+x \
  http://hello.qwerty.sh && ./hello
```

Download an archive, verify it, unpack it (without keeping the archive itself):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --sha256=70c98b2d0640b2b73c9d8adb4df63bcb62bad34b788fe46d1634b6cf87dc99a4 \
  http://download.redis.io/releases/redis-5.0.0.tar.gz | \
    tar -xvzf -
```


### Using git

Download a shell script, verify it, execute it (without keeping it):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  -o - https://github.com/rduplain/qwerty.sh.git web/hello/hello.sh | sh
```

Download a program, verify it, keep it, make it executable (then execute it):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --chmod=a+x \
  https://github.com/rduplain/qwerty.sh.git \
  web/hello/hello.sh:hello && ./hello
```

Download an entire repository (without retaining .git metadata):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  https://github.com/rduplain/qwerty.sh.git

curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --output=OUTPUT_DIRECTORY https://github.com/rduplain/qwerty.sh.git
```

Download a specific revision of a file (`-o -` writes to stdout):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  -b v0.6.3 \
  -o - https://github.com/rduplain/qwerty.sh.git qwerty.sh | head
```

Download a specific revision of a file which is not tagged or is not at the
HEAD of a branch (and note that use of `--ref` is more download intensive):

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --ref dea68e7 \
  -o - https://github.com/rduplain/qwerty.sh.git qwerty.sh | head
```

Download multiple files, verify them, keep them, make them executable:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --chmod=a+x \
  https://github.com/rduplain/qwerty.sh.git \
  qwerty.sh web/hello/hello.sh:hello.sh
```

Download multiple files, verify them, write one file to stdout while making the
others executable:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  --chmod=a+x \
  https://github.com/rduplain/qwerty.sh.git \
  LICENSE:- web/hello/hello.sh:hello.sh
```

Download multiple files, verify them, and write them to stdout:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - \
  -o - \
  https://github.com/rduplain/qwerty.sh.git \
  README.md web/README.md | less
```


### Using a Run-Command (rc) File

Run qwerty.sh in batch-mode by providing a run-command (rc) file. This approach
is useful in order to have a project download, verify, and unpack multiple
files from multiple sources _without_ tracking anything but the rc file in
version control.

An example `.qwertyrc`:

```sh
# https://qwerty.sh/

# With checksum, download shell script, verify it, keep it, make it executable.
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  --output=hello-from-checksum --chmod=a+x \
  http://hello.qwerty.sh

# With git, download shell script, verify it, keep it, make it executable.
  --chmod=a+x \
  --force --when-missing \
  https://github.com/rduplain/qwerty.sh.git \
  web/hello/hello.sh:hello-from-git
```

Call qwerty.sh:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - --rc .qwertyrc
```

This will result in two local files (`hello-from-checksum`, `hello-from-git`)
applying two separate command-line invocations of qwerty.sh, using only a
single download of the qwerty.sh program itself.

Provide multiple `--rc` flags for multiple run-command files. Add the
`--cd-on-rc` flag to have qwerty.sh change directories to that of the
run-command file when processing its commands.

Specifying multiple rc files in a pattern/glob requires quoting. Otherwise, the
shell will expand filepaths before passing them to qwerty.sh, which will fail
because `--rc` takes a single argument. For example, to specify rc files in a
directory, quote the argument with single (') or double (") quotes to delay
expansion (and use `.*` not `*` if the target rc files are hidden dotfiles):

```sh
--rc='.qwertyrc.d/*'
```

Note that the shell language has limitations when commenting with the
line-continuation backslash (`\`). A block of lines is joined as though the
backslashes and their adjacent newlines are not there. As such, no line can be
"commented-out" without moving it outside of the backslash-concatenated block
of lines, separated by newlines.

Example interpreted as a stand-alone comment followed by an rc line:

```sh
# --flag=value \

--flag=value
```

Example interpreted as a comment only, without any rc lines:

```sh
# --flag=value \
--flag=value
```


### Conditional Execution

Provide processor architecture and operating system details to qwerty.sh to
conditionally execute a command:

```
  --arch=ARCHITECTURE        Run only if `uname -m` matches.
  --sys=OPERATING_SYSTEM     Run only if `uname -s` matches.
  --when=COMMAND             Run only if COMMAND is successful.
```

For example, on flags `--arch=x86_64 --sys=Linux`, qwerty.sh will only proceed
on 64-bit x86 Linux machines. On `--sys=Linux` alone (no `--arch` given),
qwerty.sh will only proceed on Linux machines (of any architecture).

Values are case-insensitive and will match specifically what is reported by
`uname`: `-m` and `-s` for architecture and kernel/system, respectively. Pass
multiple `--sys` and `--arch` flags as needed to support target platforms. Only
one match of each category is needed to continue execution.

An `--all-sub-arch` flag is accepted in order to support architectures which
have multiple sub-architectures. Namely, ARM systems report a wide variety of
names in `uname -m` (`armv6`, `armv6-m`, ..., `armv7l`, ...). On `--arch=arm
--all-sub-arch`, qwerty.sh will proceed on all platforms that report an
architecture starting with `arm`. More broadly, `--all-sub-arch` matches all
`uname -m` output that starts with the given `--arch` value.

Conditional execution is especially useful when downloading platform-dependent
binaries for projects that run on a variety of platforms. A run-command (rc)
file can specify qwerty.sh invocations across multiple platforms, and qwerty.sh
will skip any commands for which the system conditions are not met. This
approach allows a single qwerty.sh invocation to download platform-dependent
files and binaries without additional logic.


### Conditional Execution, Full Example

An example to put it all together, `hosts.qwertyrc`:

```sh
# https://qwerty.sh/

# GNU/Linux 64-bit
  --sys=linux --arch=x86_64 \
  --sha256=baae9a4ccb17b3f9e0b868e261e39356774955a68084d3653a1d7e773dea616d \
  --output="$HOME"/bin/hosts --chmod=755 \
  https://github.com/rduplain/hosts/releases/download/v1.1/hosts-v1.1-x86_64-linux-gnu

# GNU/Linux on ARM, incl. Raspberry Pi
  --sys=linux --arch=arm --all-sub-arch \
  --sha256=31762e1448834bd3cdd76a708aa0e53cbc88144ca0151077f58d5058e6eca6ec \
  --output="$HOME"/bin/hosts --chmod=755 \
  https://github.com/rduplain/hosts/releases/download/v1.1/hosts-v1.1-arm-linux-gnueabihf

# Mac OS X, 64-bit
  --sys=darwin --arch=x86_64 \
  --sha256=6b741620cd517e23ad1748fc6193e3cdf099fb32d16c26a2edb93d847ee3635f \
  --output="$HOME"/bin/hosts --chmod=755 \
  https://github.com/rduplain/hosts/releases/download/v1.1/hosts-v1.1-x86_64-apple-darwin

# FreeBSD 64-bit
  --sys=freebsd --arch=amd64 \
  --sha256=412d4e850d3a26685a6954f75d40665fd128a42712a4d4572bd1371232795a44 \
  --output="$HOME"/bin/hosts --chmod=755 \
  https://github.com/rduplain/hosts/releases/download/v1.1/hosts-v1.1-x86_64-freebsd
```

Then:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s - --rc hosts.qwertyrc
```


### Event Hooks

Hook shell expressions into qwerty.sh at specific events during its runtime.
Each hook supports repeat command-line flags and runs the given shell
expressions in order.

All shell expressions passed to qwerty.sh can be quoted in order to include
shell features of pipelines and redirection. Further, qwerty.sh logs only to
stderr in order to preserve stdout for download and hook output.


#### On Start

Hooks run on start, after parsing arguments and before conditional execution.

The on-start hook runs in the original working directory of qwerty.sh.


#### On Match

Hooks run after conditions match; run when no conditions are given.
See [_Conditional Execution_](#conditional-execution).

The on-match hook runs in the original working directory of qwerty.sh.


#### On Download

Hooks run on (after) download and before writing output.

This is useful in unpacking zipped binary executables, especially when using
run-command (rc) files to specify downloads for multiple supported platforms.

The following example downloads a .zip matching the given checksum, unzips a
binary, outputs it to a specific filepath, makes it executable, and only runs
if this resulting file does not exist on repeat runs of qwerty.sh (which is
essential to prevent qwerty.sh from rejecting the resulting file on its next
run, because the checksum of the resulting file is not the same as that of the
specified .zip download):

```sh
# Skip the $QWERTY_SH line when using .qwertyrc files.
eval "$QWERTY_SH" \
  --sys=linux --arch=x86_64 \
  --when='! test -e bin/program' \
  --sha256=1234567890abcdef \
  --output=bin/program --chmod=a+x \
  --on-download='unzip $DOWNLOAD && mv program $DOWNLOAD' \
  http://dist.example.com/program_1.0_linux_amd64.zip
```

The on-download hook runs in the temporary working directory of the download
before qwerty.sh writes its output. When using a checksum, an on-download hook
can substitute output by overwriting the file at `$DOWNLOAD`. When using git,
an on-download hook can modify any path within the cloned repository.


#### On Output

Hooks run after writing output.

This is useful in unpacking archived directories and running setup commands.
Note that these steps are often best run within a script or Makefile that calls
qwerty.sh, with the on-output hook provided for cases where a project would
prefer a single, complete qwerty.sh invocation to run setup commands.

The following example downloads an archive matching the given checksum, unpacks
it to a relative directory, and only runs if a resulting file does not exist on
repeat runs of qwerty.sh:

```sh
# Skip the $QWERTY_SH line when using .qwertyrc files.
eval "$QWERTY_SH" \
  --when='! test -e .usr/local/project-1.0' \
  --sha256=1234567890abcdef \
  --output=.usr/src/project-1.0.tar.gz \
  --on-output='mkdir -p .usr/local' \
  --on-output='cd .usr/local; tar -xf ../src/project-1.0.tar.gz' \
  http://dist.example.com/project-1.0.tar.gz
```

The on-output hook runs in the original working directory of qwerty.sh.

To build a static binary from the qwerty.sh download, consider an on-download
hook instead of on-output with build steps. Substitute the download with the
resulting binary when using a checksum or specify the resulting build filepath
for output when using git.


#### On Finish

Hooks run on finish, after qwerty.sh finishes its full main routine.

Note that with run-command (rc) files, this hook runs at the finish of each rc
line invocation.

The on-finish hook runs in the original working directory of qwerty.sh.


### Trust

**Only run code from trusted sources. This includes copy/paste qwerty.sh
invocations and run-command (rc) .qwertyrc files.**

The qwerty.sh project has a single focus: provide a script as a service.

The script downloads and runs locally; no information given to the script is
provided to the qwerty.sh server. When running qwerty.sh, only the `curl`
portion of the command line is known to the qwerty.sh server, which only
indicates a request to download the qwerty.sh script.

The qwerty.sh script is provided over HTTPS which is encrypted by [Let's
Encrypt](https://letsencrypt.org/). Having a trusted certificate authority
through _Let's Encrypt_ is essential in getting a trusted qwerty.sh script.
This HTTPS encryption initiates a web of trust:

* Determine details (e.g. a checksum or git) which validate a given file.
* Get the qwerty.sh script, knowing that it transmitted through HTTPS.
* Tell the qwerty.sh script known details about the target file to download.

Harden curl usage:

```sh
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s -
```

qwerty.sh is available as specific versions to further guarantee repeatability.

Skeptical users can fork the qwerty.sh project on GitHub and set a shell
environment variable for the conventional `QWERTY_SH` to the fork's resulting
`https://raw.githubusercontent.com/.../qwerty.sh` URL:

```sh
QWERTY_SH="curl --proto '=https' --tlsv1.2 -sSf HTTPS_URL_HERE | sh -s -"
```

See [below](#alternative-hosting-and-local-usage) for details on downloading
qwerty.sh for local usage.

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
developers and builds will skip the verification step, or not even consider it!
Verification is about trust and repeatability; the only way to know that you
downloaded what you expected is to know up front what you are expecting.


### Why "qwerty.sh"?

Bootstrap a toolchain on an internet-connected Unix-like system with just one
dependency: a keyboard.

```sh
alias qwerty.sh="curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | \
  QWERTY_SH_PROG=qwerty.sh sh -s -"

qwerty.sh [OPTION...] URL [...]
```

Let's take a moment to reflect on the profundity of this alias. A standard Unix
shell can extend with a hosted script that behaves just like any other command
in the shell.


### White Label

qwerty.sh supports vendoring, to allow an external project to wrap or rename
qwerty.sh in its operation. For example, a `cmd` with subcommands could have
`cmd download` call out to a local qwerty.sh file:

```sh
QWERTY_SH_PROG='cmd download' path/to/qwerty.sh "$@"
```

In this mode, qwerty.sh will function as usual but rewrite all messages and
usage to indicate `$QWERTY_SH_PROG` instead of `qwerty.sh`.

Importantly, this approach allows external projects to download qwerty.sh as-is
without modification. With this approach, updating the vendored qwerty.sh
program is just a download of a new version:

```sh
mkdir -p path/to/
curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh > path/to/qwerty.sh
chmod a+x path/to/qwerty.sh
```

Calling qwerty.sh via `curl` also supports `$QWERTY_SH_PROG`.


### Alternative Hosting and Local Usage

Alternative hosting of qwerty.sh is provided by GitHub [through its "raw" file
hosting][raw]; use a version tag by changing [`master`][raw] in the URL to a
version tag, e.g. [`v0.7`][raw v].

[raw]: https://raw.githubusercontent.com/rduplain/qwerty.sh/master/qwerty.sh
[raw v]: https://raw.githubusercontent.com/rduplain/qwerty.sh/v0.7/qwerty.sh

To run qwerty.sh locally, download and run it:

* Download qwerty.sh from <https://qwerty.sh>, which is always the latest
  release of qwerty.sh. Optionally include a version,
  e.g. <https://qwerty.sh/v0.7>.
* ... or from GitHub [through its "raw" file hosting][raw]; use a version tag
  by changing [`master`][raw] in the URL to a version tag, e.g. [`v0.7`][raw
  v].
  * Recommended: use a version tag, e.g. [`v0.7`][raw v]. Though
    [`master`][raw] is stable, it consistently refers to a pre-release; prefer
    a release version when downloading qwerty.sh.
* Ensure that the resulting file is executable: `chmod a+x /path/to/qwerty.sh`.
* Call `/path/to/qwerty.sh` directly or include it in the shell's `PATH`.
  * See `qwerty.sh --help` for help.

It's good practice to have scripts call `$QWERTY_SH` (or `eval "$QWERTY_SH"`)
instead of a hard-coded `curl` invocation, as to allow dynamic reconfiguration
to substitute a locally downloaded `qwerty.sh` program.

Start with `QWERTY_SH` value:

```sh
QWERTY_SH="curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s -"
```

Match project requirements by adjusting the URL or referring to a locally
downloaded qwerty.sh program:

```sh
QWERTY_SH="curl --proto '=https' --tlsv1.2 -sSf CUSTOM_URL_HERE | sh -s -"
QWERTY_SH="sh /path/to/qwerty.sh"
QWERTY_SH="/path/to/qwerty.sh"
```

Optionally, add `QWERTY_SH_URL` to dynamically configure the qwerty.sh URL:

```sh
QWERTY_SH="curl --proto '=https' --tlsv1.2 -sSf $QWERTY_SH_URL | sh -s -"
```

Then adjust the URL as needed:

```sh
QWERTY_SH_URL="https://qwerty.sh"
QWERTY_SH_URL="https://qwerty.sh/v0.7"
QWERTY_SH_URL="https://raw.githubusercontent.com/rduplain/qwerty.sh/master/qwerty.sh"
QWERTY_SH_URL="https://raw.githubusercontent.com/rduplain/qwerty.sh/v0.7/qwerty.sh"
```


### Meta

Contact: community@qwerty.sh

Status: Stable, with a clear path toward a fully production-ready v1.0 release.
"Fully production-ready" means highly available hosting. See alternative
hosting options [above](#alternative-hosting-and-local-usage).

Copyright (c) 2018-2021, R. DuPlain. All rights reserved.
BSD 2-Clause License.

... with apologies to Dvorak.


[hello.sh]: https://github.com/rduplain/qwerty.sh/blob/master/web/hello/hello.sh

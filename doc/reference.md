## qwerty.sh: Reference

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
* [White Label](#white-label)
* [Why "qwerty.sh"?](#why-qwertysh)


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

1. Repeatable single-command downloads in build workflows.
2. Trusted copy/paste developer tool instructions (replacing `curl ... | sh`).
3. An easy-to-type command to bootstrap a development environment.


### Usage

On a Unix shell:

```sh
Q=https://raw.githubusercontent.com/rduplain/qwerty.sh/v0.7.1/qwerty.sh
alias qwerty.sh="curl --proto '=https' --tlsv1.2 -sSf $Q | Q=$Q sh -s -"
```

Explained:

* Set the `$Q` environment variable to a reliably hosted `qwerty.sh` script.
* Use `--proto '=https' --tlsv1.2` to configure `curl` to only accept HTTPS;
  this mitigates the risk of `curl` being redirected to a non-encrypted URL.
* Use `-sS` to silence `curl` (`-s`) but show an error (`-S`).
* Use `-f` to fail silently on server errors, to let qwerty.sh control output.
* Reference the previously set `$Q`, twice:
  - The first is simple variable substitution, give the URL to `curl`.
  - The second is to pass `$Q` to the `qwerty.sh` program, in order for
    `qwerty.sh` to provide useful help messaging. Instead of `export Q`,
    setting `Q=$Q` allows the `sh -s -` process to have `Q` in its environment
    without `export`ing/cluttering the environment of other processes
    (especially because `Q` is highly contextual to qwerty.sh).
* Pipe to `sh` to run `qwerty.sh` locally.
* Invoking `sh -s -` allows for all additional command-line arguments to be
  passed to `qwerty.sh` (instead of to `sh`).

The `--help` flag shows full usage.
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
found on Unix platforms (SUSv4), and makes every effort to provide a simple,
clear error message in the event that a dependency is missing.


### Using a Checksum

Download a shell script, verify it, execute it (without keeping it):

```sh
qwerty.sh \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  http://hello.qwerty.sh | sh
```

Download a program, verify it, keep it, make it executable (then execute it):

```sh
qwerty.sh \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  --output=hello --chmod=a+x \
  http://hello.qwerty.sh && ./hello
```

Download an archive, verify it, unpack it (without keeping the archive itself):

```sh
qwerty.sh \
  --sha256=70c98b2d0640b2b73c9d8adb4df63bcb62bad34b788fe46d1634b6cf87dc99a4 \
  http://download.redis.io/releases/redis-5.0.0.tar.gz | \
    tar -xvzf -
```


### Using git

Download a shell script, verify it, execute it (without keeping it):

```sh
qwerty.sh \
  -o - https://github.com/rduplain/qwerty.sh.git web/hello/hello.sh | sh
```

Download a program, verify it, keep it, make it executable (then execute it):

```sh
qwerty.sh \
  --chmod=a+x \
  https://github.com/rduplain/qwerty.sh.git \
  web/hello/hello.sh:hello && ./hello
```

Download an entire repository (without retaining .git metadata):

```sh
qwerty.sh https://github.com/rduplain/qwerty.sh.git

qwerty.sh --output=OUTPUT_DIRECTORY https://github.com/rduplain/qwerty.sh.git
```

Download a specific revision of a file (`-o -` writes to stdout):

```sh
qwerty.sh \
  -b v0.6.3 \
  -o - https://github.com/rduplain/qwerty.sh.git qwerty.sh | head
```

Download a specific revision of a file which is not tagged or is not at the
HEAD of a branch (and note that use of `--ref` is more download intensive):

```sh
qwerty.sh \
  --ref dea68e7 \
  -o - https://github.com/rduplain/qwerty.sh.git qwerty.sh | head
```

Download multiple files, verify them, keep them, make them executable:

```sh
qwerty.sh \
  --chmod=a+x \
  https://github.com/rduplain/qwerty.sh.git \
  qwerty.sh web/hello/hello.sh:hello.sh
```

Download multiple files, verify them, write one file to stdout while making the
others executable:

```sh
qwerty.sh \
  --chmod=a+x \
  https://github.com/rduplain/qwerty.sh.git \
  LICENSE:- web/hello/hello.sh:hello.sh
```

Download multiple files, verify them, and write them to stdout:

```sh
qwerty.sh \
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
qwerty.sh --rc .qwertyrc
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
qwerty.sh --rc hosts.qwertyrc
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
# Skip the first line (`qwerty.sh \`) when using .qwertyrc files.
qwerty.sh \
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

The qwerty.sh script is provided over HTTPS. Having a trusted certificate
authority is essential in getting a trusted qwerty.sh script. This HTTPS
encryption initiates a web of trust:

* Determine details (e.g. a checksum or git) which validate a given file.
* Get the qwerty.sh script, knowing that it transmitted through HTTPS.
* Tell the qwerty.sh script known details about the target file to download.

Ideally everything could be verified against signed artifacts, i.e. GPG. The
entire purpose of `qwerty.sh` is to acknowledge the reality that many files are
downloaded without any verification whatsoever (neither git nor checksum) and
piped freely into `sh` and other interpreters, (!!!) and identifies a trusted
HTTPS connection as the lowest common denominator in trust.

Skeptical users can fork the qwerty.sh project on GitHub or elsewhere:

```
Q=https://.../qwerty.sh/v0.7.1/qwerty.sh  # Set URL of fork here.
alias qwerty.sh="curl --proto '=https' --tlsv1.2 -sSf $Q | Q=$Q sh -s -"
```

Alternatively, run a `qwerty.sh` web server.

[BSD 2-Clause License](../LICENSE)


### The qwerty.sh Web Service

See: [web/README.md](../web/README.md#readme)


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
curl --proto '=https' --tlsv1.2 -sSf $Q > path/to/qwerty.sh
chmod a+x path/to/qwerty.sh
```

Calling `qwerty.sh` via `curl` also supports `$QWERTY_SH_PROG`.


### Why "qwerty.sh"?

Bootstrap a toolchain on an internet-connected Unix-like system with just one
dependency: a keyboard.


[hello.sh]: https://github.com/rduplain/qwerty.sh/blob/master/web/hello/hello.sh

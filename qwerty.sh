#!/bin/sh
# qwerty.sh: download, verify, and unpack files in a single command.
#
# Copyright (c) 2018-2020, R. DuPlain. All rights reserved.
# README: https://github.com/rduplain/qwerty.sh#readme
# Contact: community@qwerty.sh -- See footer for BSD 2-Clause License.

VERSION=v0.6.2

usage() {
    exists "$@" && stderr "$PROG: $(red "$@")" && return 2

    stderr "usage: curl -sSL qwerty.sh        | sh -s - [OPTION...] URL [...]"
    stderr "       curl -sSL qwerty.sh/v0.6.2 | sh -s - [OPTION...] URL [...]"
    stderr
    stderr "harden usage with:"
    stderr
    stderr "  curl --proto '=https' --tlsv1.2 -sSf https://qwerty.sh | sh -s -"
    stderr
    stderr "using a checksum:"
    stderr
    stderr "  URL                        A file to download."
    stderr
    stderr "  --sha224=..."
    stderr "  --sha256=..."
    stderr "  --sha384=..."
    stderr "  --sha512=..."
    stderr
    stderr "  --md5=...    (weak)"
    stderr "  --sha1=...   (weak)"
    stderr
    stderr "  --skip-rej                 Skip writing .rej file on failure."
    stderr
    stderr "using git:"
    stderr
    stderr "  ... URL"
    stderr "  ... URL <file>..."
    stderr "  ... URL <repo_file>:<local_file>..."
    stderr
    stderr "  URL                        A repository."
    stderr "  file                       Download file within repository."
    stderr "  repo_file:local_file       Download file to this local path."
    stderr
    stderr "  -b, --ref=REF, --tag=TAG   Clone repository at this reference."
    stderr "                             Option --ref is useful when a ref is"
    stderr "                             untagged and not HEAD of a branch;"
    stderr "                             --ref clones the full repo history"
    stderr "                             and is more download-intensive."
    stderr "  -f, --force                Force overwriting files."
    stderr "  --when-missing             When used with --force, only clone"
    stderr "                             repository when one or more files"
    stderr "                             are missing on the local system."
    stderr "  -k, --keep                 Keep the .git directory after clone."
    stderr "                             Note: -b, --tag have shallow clones."
    stderr
    stderr "using a run-command (rc) file:"
    stderr
    stderr "  --rc=FILE                  File containing qwerty.sh arguments."
    stderr "                             Each line in the file is treated as"
    stderr "                             arguments to a qwerty.sh call;"
    stderr "                             multiple rc files supported."
    stderr "  --cd-on-rc                 Change directories to that of rc file"
    stderr "                             when processing its commands."
    stderr
    stderr "output options:"
    stderr
    stderr "  -o, --output=FILEPATH      Download to this location."
    stderr "  --chmod=MODE               Change mode of downloaded file(s)."
    stderr
    stderr "general options:"
    stderr
    stderr "  -h, --help                 Display this help message."
    stderr "  -V, --version              Display '$PROG $VERSION' to stdout."
    stderr
    stderr "conditional execution:"
    stderr
    stderr '  --arch=ARCHITECTURE        Run only if `uname -m` matches.'
    stderr '  --sys=OPERATING_SYSTEM     Run only if `uname -s` matches.'
    stderr "  --when=COMMAND             Run only if COMMAND is successful."
    stderr
    stderr "  --all-sub-arch             Support partial --arch matches."
    stderr
    stderr '`sh -s -` sends all arguments which follow to the stdin script.'
    return 2
}

main() {
    reset
    set_traps
    determine_program_name "$@"

    parse_arguments "$@"

    if ! platform_matches; then
        clear_traps
        return
    fi

    if using_rc; then
        run_commands
    elif using_checksum; then
        if ! valid_download_exists; then
            given curl openssl
            create_temp_dir
            download
            checksums_or_rej
            write_download_output
        fi
    else
        given git
        create_temp_dir
        if validate_filepaths_before_clone; then
            clone
            validate_filepaths_after_clone
            prepare_clone_output
            write_clone_output
        fi
    fi
    remove_temp_dir
    clear_traps
}


### Global variables ###

# Exit immediately if a command error or non-zero return occurs.
set -e

reset() {
    # Reset global variables.

    # Global runtime configuration variables:
    PROG=qwerty.sh       # Name of program.
    BASEPROG="$PROG"     # Static identifier for use in temporary names.
    TEMP_DIR=            # Path to program's temporary directory.
    WORKING_DIR="$PWD"   # Path of program's working directory.

    # Checksum runtime configuration variable:
    DOWNLOAD=            # Temporary path of downloaded file.

    # Clone runtime configuration variables:
    CLONE_FILEPATH=      # Temporary path of cloned repository.
    CLONE_FULL=          # Clone full repository (when needed by revision).
    CLONE_PREPARED=      # Temporary path of output prepared from clone.
    CLONE_STDOUT=        # Temporary path of file to send to stdout.

    # Variables parsed from command line:
    ALL_SUB_ARCH=        # Support partial --arch matches.
    ARCH=                # Run only if `uname -m` matches one of these.
    ARGUMENTS=           # Additional positional arguments.
    CD_ON_RC=            # Change directories to rc file when processing it.
    CHMOD=               # Mode invocation for chmod of downloaded file.
    CLONE_REVISION=      # Branch, reference, or tag to clone.
    FORCE=               # Force overwriting files (default in checksum mode).
    KEEP=                # Keep the .git directory after clone.
    OUTPUT=              # Destination of downloaded file(s) once verified.
    RC=                  # Run-command (rc) file(s) for batch-style qwerty.sh.
    SKIP_REJ=            # Skip writing .rej file on failure.
    SYS=                 # Run only if `uname -s` matches one of these.
    URL=                 # URL of target download.
    WHEN=                # Run only if one of these commands is successful.
    WHEN_MISSING=        # With FORCE, only clone when missing local files.

    # Checksum values, parsed from command line:
    MD5=
    SHA1=
    SHA224=
    SHA256=
    SHA384=
    SHA512=

    # Behavior overrides:
    QWERTY_SH_USE_REF="${QWERTY_SH_USE_REF-}"

    # Dynamic global variable to support white-label qwerty.sh invocation:
    QWERTY_SH_PROG="${QWERTY_SH_PROG-}"

    # Path of working directory at program start.
    QWERTY_SH_PWD="${QWERTY_SH_PWD-$PWD}"
}

pack_arguments() {
    # Print packed data of values parsed from command line, for validation.
    #
    # Keep in sync with list (above) of variables parsed from command line.
    # Note that conditional execution options are omitted; they always apply.

    printf %s \
           "$URL$ARGUMENTS" \
           "$MD5$SHA1$SHA224$SHA256$SHA384$SHA512" \
           "$CD_ON_RC$CHMOD$CLONE_REVISION$FORCE$KEEP$OUTPUT$RC$SKIP_REJ" \
           "$WHEN_MISSING"
}


### Shell Cookbook: General utilities without global variables ###

## Utilities to verify external dependencies ##

given() {
    # Check that the given commands exist.

    for command in "$@"; do
        if ! which "$command" > /dev/null; then
            if exists "$PROG"; then
                stderr "$PROG: cannot find required program: $command"
            else
                stderr "cannot find required program: $command"
            fi
            return 3
        fi
    done
}


## Checksum ##

checksum() {
    # Verify checksum of file, exiting non-zero if hash does not match.

    if [ $# -ne 3 ]; then
        stderr "usage: checksum FILENAME sha1|sha256|... HASH"
        return 2
    fi

    filepath="$1"
    hash_algorithm="$2"
    hash_value="$3"
    shift 3

    case "$hash_algorithm" in
        "md5" | "sha1" | "sha224" | "sha256" | "sha384" | "sha512")
            dgst_value=$(openssl_dgst "$filepath" $hash_algorithm) || return $?

            # Print a legible standalone section of checksum values to stderr.
            case "$hash_algorithm" in
                "md5")
                    pad="----"
                    ;;
                "sha1")
                    pad="---"
                    ;;
                *)
                    pad="-"
                    ;;
            esac
            stderr "--- $hash_algorithm $pad$(repleat "-" $dgst_value)"
            stderr "Expected:   $hash_value"
            if [ "$hash_value" = "$dgst_value" ]; then
                stderr "$(green Downloaded): $dgst_value"
            else
                stderr "$(red Downloaded): $dgst_value"
            fi
            stderr "------------$(repleat "-" $dgst_value)"

            if [ "$hash_value" != "$dgst_value" ]; then
                stderr "Error: $hash_algorithm mismatch."
                return 1
            fi

            # Success. Provide suggestion to upgrade on weaker algorithms.
            case "$hash_algorithm" in
                "md5" | "sha1")
                    stderr "$(yellow "Using $hash_algorithm. Next time use:")"
                    stderr
                    stderr "    --sha256=$(openssl_dgst "$filepath" sha256)"
                    stderr
                    stderr "... assuming no $hash_algorithm collision."
                ;;
            esac
            ;;
        * )
            stderr "checksum: unknown hash algorithm: $hash_algorithm"
            return 2
            ;;
    esac
}

openssl_dgst() {
    # Print openssl digest value of file checksum to stdout.
    #
    # Unlike `checksum`, this does not validate selection of given algorithm.

    given openssl

    if [ $# -ne 2 ]; then
        stderr "usage: openssl_dgst FILENAME sha1|sha256|..."
        return 2
    fi

    filepath="$1"
    hash_algorithm="$2"
    shift 2

    dgst_output=$(openssl dgst -$hash_algorithm "$filepath")
    dgst_exit=$?

    if [ $dgst_exit -ne 0 ]; then
        stderr "openssl dgst failed with non-zero status: $dgst_exit"
        return $dgst_exit
    fi

    # Parse checksum output and trim spaces.
    dgst_value=$(printf %s "$dgst_output" | awk -F= '{ print $2 }')
    dgst_value=$(printf %s "$dgst_value" | tr -d "[:space:]")

    if ! exists "$dgst_value"; then
        stderr "Unable to parse hash value from openssl dgst call."
        return 3
    fi

    printf %s $dgst_value
}


## Shell language improvements ##

contains() {
    # Check whether first argument exists in remaining arguments.
    #
    # Example:
    #
    #     contains "/" "foo/bar/"

    match="$1"
    shift

    case "$*" in *"$match"*) return 0;; esac; return 1
}

endswith() {
    # Check whether first argument exists at the end of remaining arguments.
    #
    # Example:
    #
    #     endswith "bar/" "/foo/bar/"

    substr="$1"
    shift

    case "$*" in *"$substr") return 0;; esac; return 1
}

exists() {
    # Check whether argument is not empty, i.e. test whether a variable exists.
    #
    # Example:
    #
    #     exists "$VAR"

    [ _"$*" != _ ]
}

lower() {
    # Print argument to stdout, converting uppercase letters to lowercase.

    echo "$@" | tr "[:upper:]" "[:lower:]"
}

quote_arguments() {
    # Output argument array to stdout in a format for saving.
    #
    # The argument array can include newlines and ' quotes.
    # This:
    #
    #     foo
    #     bar'baz
    #     one two
    #
    # ... is saved as:
    #
    #     'foo' \
    #     'bar'\''baz' \
    #     'one two' \
    #
    #
    # ... where the final line above has whitespace to continue the
    #     previous/final backslash without effect (according to sh grammar).
    #
    # Formatting a string with these quoted arguments allows that string to be
    # saved as a variable which can then be passed to shell's builtin `set`
    # which parses the variable as though its contents were passed on the
    # command line verbatim.
    #
    # Example:
    #
    #     ARGUMENTS=$(quote_arguments "$@") # Save "$@".
    #     eval "set -- $ARGUMENTS"          # Load "$@".

    for arg in "$@"; do
        quote_argument "$arg"
    done

    # Close array. See function comment block above.
    echo " "
}

quote_argument() {
    # Output argument within array to stdout in a format for saving.
    #
    # See `quote_arguments`.

    #       Quoted argument.
    #       |  Output line continuation \, escaped twice.
    #       |  |   Newline, escaped twice.
    printf "%s \\\\\\n" "$(quote "$@")"
}

quote() {
    # Output argument wrapped in ' quotes, to stdout.

    printf %s\\n "$@" | \
        #    Replace ' characters with '\''.
        #    |    Output \ (for \'), escaped twice.
        #    |               Insert leading '.
        #    |               |         Append trailing '.
        sed "s/'/'\\\\''/g;  1s/^/'/;  \$s/\$/'/"
}

startswith() {
    # Check whether first argument exists at the start of remaining arguments.
    #
    # Example:
    #
    #     startswith "/foo" "/foo/bar/"

    substr="$1"
    shift

    case "$*" in "$substr"*) return 0;; esac; return 1
}


## Utilities for standard I/O ##

stdout() {
    # Echo all arguments to stdout.
    #
    # Provided for parity with stderr function.

    echo "$@"
}

stderr() {
    # Echo all arguments to stderr.
    #
    # Be sure to return/exit with an error code if applicable, after calling.

    echo "$@" >&2
}

stdout_isatty() {
    # Check whether stdout is open and refers to a terminal.

    [ "$ISATTY" = "true" ] || [ -t 1 ]
}

stderr_isatty() {
    # Check whether stderr is open and refers to a terminal.

    [ "$ISATTY" = "true" ] || [ -t 2 ]
}

repleat() {
    # Echo repeat replacement character for the width of given value.

    replacement="$1"
    shift

    echo "$@" | tr "[:print:]" "$replacement"
}

colorize() {
    # Print line to stdout, with given color code, if stderr is a terminal.

    color="$1"
    shift

    if stderr_isatty; then
        printf "\033[1;${color}m%s\033[0m" "$*"
    else
        echo "$*"
    fi
}

blue() {
    # Print line to stdout, in blue, if stderr is a terminal.

    colorize 34 "$@"
}

green() {
    # Print line to stdout, in green, if stderr is a terminal.

    colorize 32 "$@"
}

yellow() {
    # Print line to stdout, in yellow, if stderr is a terminal.

    colorize 33 "$@"
}

red() {
    # Print line to stdout, in red, if stderr is a terminal.

    colorize 31 "$@"
}


## Utilities for file I/O ##

files_exist() {
    # Check whether given directory contains files or directories.

    exists "$(find "$@" -mindepth 1 -maxdepth 1)"
}

isabs() {
    # Check whether a path is absolute.

    case "$*" in /*) return 0;; esac; return 1
}

iterate_files() {
    # Iterate all files at given location, including subdirectories.
    #
    # Load filepaths into an argument array as in `quote_arguments` as to allow
    # shell functions to access files without having to handle quoting or
    # escaping of filepaths.
    #
    # Example:
    #
    #     eval "set -- $(iterate_files /tmp/foo)" # Access files with "$@".

    path="$1"
    exists "$path" || path=.

    # Find all files (-type f) or (-o) symlinks (-type l) found within $path.
    #
    # The `find` command allows `-exec` to execute a subprocess on each found
    # result, and allows for arbitrarily many -exec calls (delimited with \;),
    # which `find` calls in order.
    #
    # Format an output in the `quote_arguments` format (see its docstring and
    # example) using printf and sed.
    #
    # Three execs, 1 2 3,
    # through comments, one can see,
    # which inline, cannot be.
    #
    #          Use a `sh -c` subprocess to support inner printf|sed pipeline.
    #          |       Output leading '.
    #    -exec 2       |  Terminate -exec with \;.
    #          | -exec 1  |  Continue find invocation to next line.
    #          |       |  1  |  Path {} from find, wrapped in escaped " quotes.
    #          |       |  |  1  |            Start sed command.
    #          |       |  |  |  2            | Replace ' characters with '\''.
    #          |       |  |  |  |            2 |    Output \ (for \'),
    #          |       |  |  |  |            | 2    escaped three times.
    #          |       |  |  |  |            | |    |          End sed command.
    #          |       1  1  1  |            | |    |          |
    #          2       |  |  |  2            2 2    2          2
    #          |       |  |  |  |            | |    |          |
    find "$path" \( -type l -o -type f \) \
         -exec printf "'" \; \
         -exec sh -c "printf %s \"{}\" | sed \"s/'/'\\\\\\''/g;\"" \; \
         -exec printf "' \\\\\\n" \;
    #                  | |   |
    #            -exec 3 3   3
    #                  | |   |
    #                  | |   Newline, escaped twice.
    #                  | Output line continuation \, escaped twice.
    #                  Output trailing '.

    # Close array. Continue final backslash without effect, using whitespace.
    echo " "
}

join_path() {
    # Join two paths, inserting '/' as needed, and output to stdout.
    #
    # Use only the second path if it is absolute.

    if [ $# -ne 2 ]; then
        stderr "usage: join_path PATH1 PATH2"
        return 2
    fi

    if isabs "$2"; then
        echo "$2"
    else
        if endswith "/" "$1"; then
            echo "$1$2"
        else
            echo "$1/$2"
        fi
    fi
}

merge_directories() {
    # Merge directories by moving files from source to destination directory.
    #
    # This operation retains the tree structure of the source directory,
    # writing files to their matching directory in the destination, while
    # retaining files and directories in the destination which do not exist in
    # the source directory.

    if [ $# -ne 2 ]; then
        stderr "usage: merge_directories SOURCE DESTINATION"
        return 2
    fi

    src="$1"
    dst="$2"
    shift 2

    pwd="$PWD"
    src_abs="$(cd "$src" && pwd)"
    dst_abs="$(cd "$dst" && pwd)"

    cd "$src_abs"
    eval "set -- $(iterate_files .)"

    cd "$dst_abs"

    for file in "$@"; do
        file="$(strip_rel "$file")"
        src_file="$(join_path "$src_abs" "$file")"
        dst_file="$(join_path "$dst" "$file")"
        dst_file="$(strip_rel "$dst_file")"
        stderr "$dst_file"
        mkdirs "$(dirname "$dst_file")"
        mv "$src_file" "$dst_file"
    done

    cd "$pwd"
}

mkdirs() {
    # Make a directory, making all parent directories in the process.
    #
    # While `mkdir -p` is useful, this allows invocation with variables which
    # may result in empty invocation.
    #
    # Example:
    #
    #     mkdirs "$(dirname "$VAR")"

    for dir in "$@"; do
        mkdir -p "$dir"
    done
}

strip_rel() {
    # Output given path, stripped of leading './' if found.

    if startswith "./" "$*"; then
        printf %s "$*" | cut -c 3-
    else
        echo "$@"
    fi
}


### Tasks and utilities which use global variables ###

## Tasks in determining whether system matches conditions for execution ##

platform_matches() {
    # Check whether local system matches given execution conditions.

    if ! exists "$ARCH$SYS$WHEN"; then
        # No conditions given.
        return
    fi

    platform_matches_fail=

    # Begin composing status line to stderr with each condition tested.
    printf %s "$PROG: conditional execution: " >&2

    if exists "$ALL_SUB_ARCH"; then
        printf %s "--all-sub-arch " >&2
    fi

    eval "set -- $ARCH"

    arch_match=
    arch_hint=

    for arch in $@; do
        match=$(lower "$arch")
        found=$(lower "$(uname -m)")

        if exists "$ALL_SUB_ARCH" && startswith "$match" "$found"; then
            arch_match="$arch"
            arch_hint="$(uname -m)"
            printf %s "$(green --arch=$arch) " >&2
        elif [ "$match" = "$found" ]; then
            arch_match="$arch"
            printf %s "$(green --arch=$arch) " >&2
        else
            printf %s "--arch=$arch " >&2
        fi
    done

    eval "set -- $SYS"

    sys_match=

    for sys in $@; do
        match=$(lower "$sys")
        found=$(lower "$(uname -s)")

        if [ "$match" = "$found" ]; then
            sys_match="$sys"
            printf %s "$(green --sys=$sys) " >&2
        else
            printf %s "--sys=$sys " >&2
        fi
    done

    eval "set -- $WHEN"

    when_match=

    for when in "$@"; do
        if ! exists "$when_match" && eval "$when" > /dev/null 2>&1; then
            when_match="$when"
            printf %s "$(green --when=\'$when\') " >&2
        else
            printf %s "--when='$when' " >&2
        fi
    done

    stderr

    if exists "$ARCH"; then
        if exists "$arch_match"; then
            if exists "$arch_hint"; then
                stderr "Architecture matches $arch_match: $(green $arch_hint)."
            else
                stderr "Architecture matches $(green $arch_match)."
            fi
        else
            stderr "Architecture does not match."
            platform_matches_fail=true
        fi
    fi

    if exists "$SYS"; then
        if exists "$sys_match"; then
            stderr "System matches $(green $sys_match)."
        else
            stderr "System does not match."
            platform_matches_fail=true
        fi
    fi

    if exists "$WHEN"; then
        if exists "$when_match"; then
            stderr "Matches 'when' condition: '$(green "$when_match")'."
        else
            stderr "Does not match a 'when' command."
            platform_matches_fail=true
        fi
    fi

    if exists "$platform_matches_fail"; then
        stderr "Platform does not match. Skipping ..."
        return 1
    else
        stderr "$(green Platform matches. Proceeding ...)"
    fi
}

## Tasks when using run-command (rc) files ##

read_run_command_file() {
    # Print preprocessed lines to stdout for `while read line`.

    if [ $# -ne 1 ]; then
        stderr "usage: read_run_command_file FILENAME"
        return 2
    fi

    file="$1"
    shift

    if [ ! -e "$file" ]; then
        stderr "$PROG: no such run-command file: $file"
        return 1
    fi

    # Ultimately, each line in the run-command file is sent to the
    # shell-builtin `read` in order to parse as shell arguments while
    # supporting comments and line continuations.
    #
    # Preprocess lines to preserve backslashes, '\' to '\\'.
    # This is especially important in supporting arguments with spaces.
    #
    # Then, revert any line-continuation so that `read` correctly constructs a
    # single line from the continuation.
    sed 's,\\,\\\\,g' "$file" | \
        sed 's,\\\\[[:space:]]*$,\\,g'
}

run_commands() {
    # Run commands listed in run-command (rc) file(s).

    eval "set -- $RC"

    if exists "$cd_on_rc$CD_ON_RC"; then
        cd_on_rc=true
    fi

    for rc_file in $@; do
        cd "$QWERTY_SH_PWD"

        rc_filepath="$PWD"/"$rc_file"

        if exists "$cd_on_rc"; then
            cd "$(dirname "$rc_file")"
            rc_filepath="$PWD"/"$(basename "$rc_file")"
            WORKING_DIR="$PWD"
        fi

        if [ ! -e "$rc_filepath" ]; then
            stderr "$PROG: no such run-command file: $rc_file"
            return 1
        fi

        read_run_command_file "$rc_filepath" | while read line; do
            eval "set -- $line"
            if [ $# -gt 0 ]; then
                stderr "--- $(blue "$rc_file"): $line"
                main "$@"
            fi
        done
    done
}

## Tasks when using checksum ##

valid_download_exists() {
    # Check whether the download output exists and has a valid checksum.

    ! exists "$OUTPUT" && return 1 # No output specified.
    [ -e "$OUTPUT" ] || return 1 # No output file exists.

    if checksums "$OUTPUT"; then
        stderr "Output already exists and is valid: $(green $OUTPUT)"
        return 0
    else
        status=$?
        stderr "Output already exists but is not valid: $(red $OUTPUT)"
        return $status
    fi
}

download() {
    # Download file at URL to DOWNLOAD.

    DOWNLOAD="$TEMP_DIR"/$BASEPROG.download

    if [ -d "$URL" ]; then
        stderr "error: $PROG cannot target directories."
        return 2
    elif [ -e "$URL" ]; then
        download_file
    else
        download_url
    fi
}

download_file() {
    # "Download" a file.

    stderr "Copying file at $URL ..."
    cp -p "$URL" "$DOWNLOAD"
}

download_url() {
    # Download a URL, passing optional QWERTY_CURL_FLAGS from environment.
    #
    # Example usage from command line:
    #
    #     curl ... qwerty.sh | QWERTY_CURL_FLAGS="-v" sh -s - ...

    given curl
    report="--- $(blue $PROG)\n"
    report="${report}Location:\t%{url_effective}\n"
    report="${report}Content-Type:\t%{content_type}\n"
    report="${report}Content-Length:\t%{size_download}\n"
    curl -SL -o "$DOWNLOAD" -w "$report" $QWERTY_CURL_FLAGS "$URL" >&2
}

checksums_or_rej() {
    # Check all specified checksum values, or write .rej file.

    if checksums; then
        return 0
    else
        status=$?
    fi

    if ! exists "$SKIP_REJ"; then
        if ! exists "$OUTPUT"; then
            output_rej="stdout.rej"
        else
            output_rej="$OUTPUT.rej"
        fi
        stderr "Rejecting download: $(red $output_rej)"
        mkdirs "$(dirname "$output_rej")"
        mv "$DOWNLOAD" "$output_rej"
    fi

    return $status
}

checksums() {
    # Check all specified checksum values.

    if exists "$MD5"; then
        checksum "${1:-$DOWNLOAD}" md5 "$MD5" || return $?
    fi

    if exists "$SHA1"; then
        checksum "${1:-$DOWNLOAD}" sha1 "$SHA1" || return $?
    fi

    if exists "$SHA224"; then
        checksum "${1:-$DOWNLOAD}" sha224 "$SHA224" || return $?
    fi

    if exists "$SHA256"; then
        checksum "${1:-$DOWNLOAD}" sha256 "$SHA256" || return $?
    fi

    if exists "$SHA384"; then
        checksum "${1:-$DOWNLOAD}" sha384 "$SHA384" || return $?
    fi

    if exists "$SHA512"; then
        checksum "${1:-$DOWNLOAD}" sha512 "$SHA512" || return $?
    fi
}

write_download_output() {
    # Write download to output file according to context.

    if exists "$OUTPUT"; then
        stderr "Download is valid. Writing to $(green $OUTPUT)."
        mkdirs "$(dirname "$OUTPUT")"
        cp -p "$DOWNLOAD" "$OUTPUT"
        if exists "$CHMOD"; then
            chmod "$CHMOD" "$OUTPUT"
        fi
    elif ! stdout_isatty; then
        stderr "Download is valid. Writing to pipeline on $(green stdout)."
        stderr
        cat "$DOWNLOAD"
    else
        stderr "No command pipeline or output specified. Waiting for Godot."
    fi
}


## Tasks when cloning a repository ##

local_filepath() {
    # Output the full filepath a target local file, according to context.

    if [ $# -ne 1 ]; then
        stderr "usage: local_filepath LOCAL_FILE"
        return 2
    fi

    local_file="$1"
    shift

    if is_stdout "$local_file"; then
        echo "$local_file"
    else
        if exists "$OUTPUT" && ! is_stdout "$OUTPUT"; then
            join_path "$OUTPUT" "$local_file"
        else
            echo "$local_file"
        fi
    fi
}

humanish() {
    # Print "humanish" name of repository to stdout, given its URL.
    #
    # For example: git@github.com:owner/project.git is "project".

    url="$1"
    shift

    echo "$url" | sed -e 's,/$,,' -e 's,:*/*\.git$,,' -e 's,.*[/:],,g'
}

iterate_clone_filepaths() {
    # Build quoted array of clone full filepaths, in (repo, local) pairs.
    #
    # See `quote_arguments`.

    eval "set -- $ARGUMENTS"

    for argument in "$@"; do
        if contains ":" "$argument"; then
            repo_file=$(printf %s "$argument" | awk -F: '{ print $1 }')
            local_file=$(printf %s "$argument" | awk -F: '{ print $NF }')
        else
            repo_file="$argument"
            local_file=
        fi

        if ! exists "$local_file"; then
            if is_stdout "$OUTPUT"; then
                local_file="$OUTPUT"
            else
                local_file="$repo_file"
            fi
        fi

        # Output quoted repo filepath.
        # Support both cases of before and after CLONE_FILEPATH is set.
        if exists "$CLONE_FILEPATH"; then
            quote_argument "$(join_path "$CLONE_FILEPATH" "$repo_file")"
        else
            quote_argument "$repo_file"
        fi

        # Output quoted local filepath.
        quote_argument "$(local_filepath "$local_file")"
    done

    # Close array. See `quote_arguments`.
    echo " "
}

validate_repo_filepath() {
    # Check repo filepath and fail with stderr message if invalid.

    if [ $# -ne 1 ]; then
        stderr "usage: validate_repo_filepath REPO_FILE"
        return 2
    fi

    repo_file="$1"
    shift

    if ! exists "$CLONE_FILEPATH"; then
        # Before clone.
        if isabs "$repo_file"; then
            stderr "$PROG: file must be relative to repository: $repo_file"
            return 2
        fi
    else
        # After clone.
        if [ ! -e "$repo_file" ]; then
            stderr "$PROG: no such file in repository: $(basename $repo_file)"
            return 2
        fi
    fi
}

validate_local_filepath() {
    # Check local filepath and exit non-zero with stderr message if it exists.

    if [ $# -ne 1 ]; then
        stderr "usage: validate_local_filepath LOCAL_FILE"
        return 2
    fi

    local_file="$1"
    shift

    if ! is_stdout "$local_file" && [ -e "$local_file" ]; then
        stderr "Output already exists: $(yellow $local_file)"
        return 1
    fi
}

validate_filepaths_before_clone() {
    # Validate file paths for writing cloned file(s).
    #
    # Run this before a clone to find errors before attempting download.

    eval "set -- $(iterate_clone_filepaths)"

    cd "$WORKING_DIR"

    # Track whether existing/missing files to decide whether clone is needed.
    some_exist=
    some_missing=

    if ! exists "$@"; then
        if is_stdout "$OUTPUT"; then
            stderr "$PROG: refusing to write entire repository to stdout."
            return 2
        elif exists "$OUTPUT"; then
            if validate_local_filepath "$OUTPUT"; then
                some_missing=true
            else
                some_exist=true
            fi
        else
            if validate_local_filepath "$(humanish "$URL")"; then
                some_missing=true
            else
                some_exist=true
            fi
        fi
    fi

    while [ "$1" != "" ]; do
        repo_file="$1"
        local_file="$2"
        shift 2

        validate_repo_filepath "$repo_file"

        if validate_local_filepath "$local_file"; then
            some_missing=true
        else
            some_exist=true
        fi
    done

    if ! exists "$some_exist"; then
        return 0
    elif exists "$FORCE"; then
        if ! exists "$WHEN_MISSING"; then
            return 0
        elif exists "$some_missing"; then
            return 0
        fi
    else
        exit 1
    fi

    return 1
}

clone() {
    # Clone repository, with result at CLONE_FILEPATH.

    given git

    clone_arguments="-c advice.detachedHead=false"

    if exists "$CLONE_REVISION" && ! exists "$CLONE_FULL"; then
        clone_arguments="$clone_arguments --depth 1 --single-branch"
        clone_arguments="$clone_arguments --branch $CLONE_REVISION"
    fi

    url="$URL"
    if [ -d "$url" ]; then
        # Repository is a local directory.
        cd "$url"
        url="$PWD"
        url="file://$url" # Use file:// to support shallow clone.
    fi

    mkdirs "$TEMP_DIR"/clone
    cd "$TEMP_DIR"/clone

    stderr "--- $(blue $PROG)"
    eval "git clone $clone_arguments $url"

    if exists "$CLONE_FULL"; then
        cd "$(ls)"
        GIT_DIR=.git git checkout "$CLONE_REVISION"
        cd ..
    fi

    # Allow git to generate a humanish directory as default output.
    CLONE_FILEPATH="$PWD/$(ls)"

    if ! exists "$KEEP"; then
        rm -fr "$CLONE_FILEPATH/.git"
    fi
}

validate_filepaths_after_clone() {
    # Validate file paths for writing cloned file(s).
    #
    # Run this after a clone to find errors before writing output.

    eval "set -- $(iterate_clone_filepaths)"

    cd "$WORKING_DIR"

    if ! exists "$FORCE" && ! exists "$@" && ! exists "$OUTPUT"; then
        # Writing entire repository; validate resulting location.
        validate_local_filepath "$(basename "$CLONE_FILEPATH")"
    fi

    while [ "$1" != "" ]; do
        repo_file="$1"
        shift 2

        validate_repo_filepath "$repo_file"
    done
}

prepare_clone_output() {
    # Prepare output from clone, with result at CLONE_PREPARED.
    #
    # Output:
    #
    # * "$CLONE_PREPARED"/abs has files to transfer to / directory.
    # * "$CLONE_PREPARED"/rel has files to transfer to . directory.
    # * "$CLONE_STDOUT" is a file to write to stdout.

    eval "set -- $(iterate_clone_filepaths)"

    CLONE_PREPARED="$TEMP_DIR"/prepare
    CLONE_STDOUT="$TEMP_DIR"/stdout

    mkdirs "$CLONE_PREPARED"/abs "$CLONE_PREPARED"/rel

    if ! exists "$@"; then
        # Prepare the full clone for output.

        if exists "$CHMOD"; then
            eval "chmod $CHMOD $CLONE_FILEPATH"
        fi

        if is_stdout "$OUTPUT"; then return; fi

        if exists "$OUTPUT"; then
            if isabs "$OUTPUT"; then
                output="$CLONE_PREPARED/abs/$OUTPUT"
            else
                output="$CLONE_PREPARED/rel/$OUTPUT"
            fi
            mkdirs "$(dirname "$output")"
            if [ "$OUTPUT" = "." ]; then
                # Unpack clone files in place.
                mv "$CLONE_FILEPATH"/* "$output"
                find "$CLONE_FILEPATH" -mindepth 1 -exec mv "{}" "$output" \;
            else
                # Move cloned repository using its git-cloned humanish name.
                mv "$CLONE_FILEPATH" "$output"
            fi
        else
            cd "$CLONE_PREPARED"/rel
            mv "$CLONE_FILEPATH" .
        fi

        return
    fi

    # Prepare individual files for output.

    while [ "$1" != "" ]; do
        repo_file="$1"
        local_file="$2"
        shift 2

        if is_stdout "$local_file"; then
            if [ -e "$CLONE_STDOUT" ]; then
                cat "$repo_file" >> "$CLONE_STDOUT"
            else
                cat "$repo_file"  > "$CLONE_STDOUT"
            fi
        else
            if isabs "$local_file"; then
                local_file="$CLONE_PREPARED/abs/$local_file"
            else
                local_file="$CLONE_PREPARED/rel/$local_file"
            fi
            mkdirs "$(dirname "$local_file")"
            cp -p "$repo_file" "$local_file"
            if exists "$CHMOD"; then
                eval "chmod $CHMOD $local_file"
            fi
        fi
    done
}

write_clone_output() {
    # Write cloned output according to context, moving CLONE_PREPARED files.

    if files_exist "$CLONE_PREPARED"/abs; then
        stderr "-----------------------------------------"
        stderr "Writing output $(green files with absolute paths):"
        merge_directories "$CLONE_PREPARED"/abs /
    fi

    if files_exist "$CLONE_PREPARED"/rel; then
        cd "$WORKING_DIR"
        stderr "---------------------"
        stderr "Writing output $(green files):"
        merge_directories "$CLONE_PREPARED"/rel .
    fi

    if [ -e "$CLONE_STDOUT" ]; then
        stderr "-------------------------"
        stderr "Writing output to $(green stdout)."
        stdout_isatty && stderr "-------------------------"
        cat "$CLONE_STDOUT"
    fi
}


## Supplemental tasks ##

version() {
    # Print version to stdout.

    stdout $PROG $VERSION
}


## Utilities to simplify conditional tests ##

is_stdout() {
    # Check whether argument indicates stdout '-'.

    [ "$*" = "-" ]
}

using_checksum() {
    # Check whether using a checksum in program invocation.

    exists "$MD5$SHA1$SHA224$SHA256$SHA384$SHA512"
}

using_rc() {
    # Check whether using a run-command (rc) file in program invocation.

    exists "$RC"
}


## Utilities for clean program execution ##

create_temp_dir() {
    # Create temporary directory, available at TEMP_DIR.

    # For portability, do not rely on mktemp command-line options (i.e. `-d`).
    given mktemp
    TEMP_DIR=$(mktemp)

    rm -f "$TEMP_DIR"
    mkdir -p "$TEMP_DIR"
}

remove_temp_dir() {
    # Remove temporary directory.

    rm -fr "$TEMP_DIR"
}

set_traps() {
    # Set shell traps in order to keep it classy on program exit.
    #
    # Set an EXIT trap since ERR is not portable.
    # Be sure to `clear_traps` before exiting on success.

    trap remove_temp_dir INT TERM

    if stdout_isatty; then
        trap 'remove_temp_dir' EXIT
    else
        trap 'stdout "exit $? # Propagate error."; remove_temp_dir' EXIT
    fi
}

clear_traps() {
    # Clear shell traps.

    trap - INT TERM EXIT
}


### Argument parsing ###

determine_program_name() {
    # Determine the qwerty.sh program name based on invocation.
    #
    # Three cases:
    #
    # 1. Default:             curl -sSL qwerty.sh | sh -s -
    #                         (or a similar pipe into `sh`)
    # 2. Local:               qwerty.sh
    #                         path/to/qwerty.sh
    # 3. White-Label:         QWERTY_SH_PROG=another-program qwerty.sh

    if exists "$QWERTY_SH_PROG"; then
        PROG="$QWERTY_SH_PROG"
    elif [ "$(basename $0)" = "$PROG" ]; then
        QWERTY_SH_PROG="$PROG"
    fi
}

help() {
    # Rewrite `usage` output to support alternative qwerty.sh invocations.

    if ! exists "$QWERTY_SH_PROG"; then
        usage "$@"
        return 2
    fi

    if stderr_isatty; then
        ISATTY=true
    fi

    usage "$@" 2>&1 | \
        sed -e "/  curl .*$/d" \
            -e "/harden usage.*$/d" \
            -e "s/curl .* sh -s -/$QWERTY_SH_PROG/g" \
            -e "/sh -s -/d" | \
        cat -s - >&2

    return 2
}

parse_arguments() {
    # Parse command-line arguments.
    #
    # All command-line flags must be listed separately,
    # i.e. combined short options in the form of `-abc` are not supported.

    line="$@"

    # Loop through arguments; below is a break on first positional argument.
    while [ "$1" != "" ]; do
        if case "$1" in "-"*) true;; *) false;; esac; then
            # Argument starts with a hyphen.
            key=$(printf %s "$1" | awk -F= '{ print $1 }')
            value=$(printf %s "$1" | awk -F= '{ print $2 }')
            shift
            if ! exists "$value"; then
                value="$1"
                exists "$value" && shift
            fi
            case "$key" in
                --arch)
                    ARCH="$ARCH $(quote "$value")"
                    ;;
                -b | --tag)
                    exists "$CLONE_REVISION" && help "duplicate ref: $value"
                    CLONE_REVISION="$value"
                    ;;
                --chmod)
                    exists "$CHMOD" && help "duplicate chmod: $value"
                    CHMOD="$value"
                    ;;
                --md5)
                    exists "$MD5" && help "duplicate md5: $value"
                    MD5="$value"
                    ;;
                -o | --output)
                    exists "$OUTPUT" && help "duplicate output: $value"
                    OUTPUT="$value"
                    ;;
                --rc)
                    RC="$RC $(quote "$value")"
                    ;;
                --ref)
                    exists "$CLONE_REVISION" && help "duplicate ref: $value"
                    CLONE_FULL=true
                    CLONE_REVISION="$value"
                    ;;
                --sha1)
                    exists "$SHA1" && help "duplicate sha1: $value"
                    SHA1="$value"
                    ;;
                --sha224)
                    exists "$SHA224" && help "duplicate sha224: $value"
                    SHA224="$value"
                    ;;
                --sha256)
                    exists "$SHA256" && help "duplicate sha256: $value"
                    SHA256="$value"
                    ;;
                --sha384)
                    exists "$SHA384" && help "duplicate sha384: $value"
                    SHA384="$value"
                    ;;
                --sha512)
                    exists "$SHA512" && help "duplicate sha512: $value"
                    SHA512="$value"
                    ;;
                --sys)
                    SYS="$SYS $(quote "$value")"
                    ;;
                --when)
                    WHEN="$WHEN $(quote "$value")"
                    ;;
                *)
                    eval "set -- $(quote_arguments "$value" "$@")"
                    case "$key" in
                        --all-sub-arch)
                            ALL_SUB_ARCH=true
                            ;;
                        --cd-on-rc)
                            CD_ON_RC=true
                            ;;
                        -f | --force)
                            FORCE=true
                            ;;
                        -h | --help)
                            help
                            ;;
                        -k | --keep)
                            KEEP=true
                            ;;
                        --skip-rej)
                            SKIP_REJ=true
                            ;;
                        -V | --version)
                            version
                            exit
                            ;;
                        --when-missing)
                            WHEN_MISSING=true
                            ;;
                        *)
                            help "unrecognized option '$key'"
                            ;;
                    esac
                    ;;
            esac
        else
            # Argument does not start with a hyphen.
            URL="$1"
            shift
            break
        fi
    done

    if exists "$ALL_SUB_ARCH" && ! exists "$ARCH"; then
        help "--all-sub-arch only applies when --arch is given: $line"
    fi

    if using_rc; then
        if [ "$(pack_arguments)" != "$CD_ON_RC$RC" ]; then
            help "only --cd-on-rc accepted in calling run-command files: $line"
        fi

        # Short-circuit. Additional arguments are unused.
        return
    fi

    if using_checksum; then
        if exists "$@"; then
            help "too many arguments when using a checksum: $*"
        fi

        if exists "$CLONE_REVISION"; then
            help "invalid repository option in checksum mode: $CLONE_REVISION"
        fi

        if exists "$KEEP"; then
            help "-k, --keep only applies when using a repository: $line"
        fi
    fi

    for argument in "$@"; do
        if case "$argument" in "-"*) true;; *) false;; esac; then
            # Argument starts with a hyphen.
            help "provide options before positional arguments: $argument"
        fi
    done

    if exists "$CD_ON_RC" && ! exists "$RC"; then
        help "--cd-on-rc only applies when --rc is given: $line"
    fi

    if exists "$WHEN_MISSING" && ! exists "$FORCE"; then
        help "--when-missing only applies when -f, --force is given: $line"
    fi

    if ! exists "$URL"; then
        help "provide a URL for download."
    fi

    if exists "$QWERTY_SH_USE_REF"; then
        CLONE_FULL=true
    fi

    ARGUMENTS=$(quote_arguments "$@")
}


### Program execution ###

main "$@"

# BSD 2-Clause License.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
#     * Redistributions of source code must retain the above copyright notice,
#       this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
# ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
# LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
# CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
# SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
# INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
# CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
# ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
# POSSIBILITY OF SUCH DAMAGE.
#
# See header for usage, contact, and copyright information.

#!/bin/sh
# qwerty.sh: download, verify, and unpack files in a single command.
#
# Copyright (c) 2018, Ron DuPlain. All rights reserved.
# README: https://github.com/rduplain/qwerty.sh#readme
# Contact: community@qwerty.sh -- See footer for BSD 2-Clause License.

VERSION=v0.4

usage() {
    exists "$@" && stderr "$PROG: $(red "$@")" && stderr # Optional message.

    stderr "usage: curl -sSL qwerty.sh        | sh -s - [OPTION...] URL [...]"
    stderr "       curl -sSL qwerty.sh/v0.3.5 | sh -s - [OPTION...] URL [...]"
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
    stderr "  output_dir                 Output directory for repository downloads."
    stderr "  file                       Download file within repository."
    stderr "  repo_file:local_file       Download file to this local path."
    stderr
    stderr "  -b, --ref=REF, --tag=TAG   Clone repository at this reference."
    stderr "  -f, --force                Force overwriting files."
    stderr
    stderr "output options:"
    stderr
    stderr "  -o, --output=FILEPATH      Download to this location."
    stderr "  --chmod=MODE               Change mode of downloaded file(s)."
    stderr
    stderr "general options:"
    stderr
    stderr "  -h, --help                 Display this usage message."
    stderr "  -V, --version              Display '$PROG $VERSION' to stdout."
    stderr
    stderr '`sh -s -` sends all arguments which follow to the stdin script.'
    return 2
}

main() {
    set_traps

    parse_arguments "$@"
    if using_checksum; then
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
        validate_filepaths_before_clone
        clone
        validate_filepaths_after_clone
        prepare_clone_output
        write_clone_output
    fi
    remove_temp_dir
    clear_traps
}


### Global variables ###

# Exit immediately if a command error or non-zero return occurs.
set -e

# Global runtime configuration variables:
PROG=qwerty.sh       # Name of program.
TEMP_DIR=            # Path to program's temporary directory.
WORKING_DIR="$PWD"   # Path of working directory at program start.

# Checksum runtime configuration variable:
DOWNLOAD=            # Temporary path of downloaded file.

# Clone runtime configuration variable:
CLONE_FILEPATH=      # Temporary path of cloned repository.
CLONE_PREPARED=      # Temporary path of output prepared from clone.
CLONE_STDOUT=        # Temporary path of file to send to stdout.

# Variables parsed from command line:
ARGUMENTS=           # Additional positional arguments.
CHMOD=               # Mode invocation for chmod of downloaded file.
CLONE_REVISION=      # Branch, reference, or tag to clone.
FORCE=               # Force overwriting files (default in checksum mode).
OUTPUT=              # Destination of downloaded file(s) once verified.
SKIP_REJ=            # Skip writing .rej file on failure.
URL=                 # URL of target download.

# Checksum values, parsed from command line:
MD5=
SHA1=
SHA224=
SHA256=
SHA384=
SHA512=


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
                    pad='----'
                    ;;
                "sha1")
                    pad='---'
                    ;;
                *)
                    pad='-'
                    ;;
            esac
            stderr "--- $hash_algorithm $pad$(repleat '-' $dgst_value)"
            stderr "expected:   $hash_value"
            if [ "$hash_value" = "$dgst_value" ]; then
                stderr "$(green downloaded): $dgst_value"
            else
                stderr "$(red downloaded): $dgst_value"
            fi
            stderr "------------$(repleat '-' $dgst_value)"

            if [ "$hash_value" != "$dgst_value" ]; then
                stderr "error: $hash_algorithm mismatch."
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
        return $dsgt_exit
    fi

    # Parse checksum output and trim spaces.
    dgst_value=$(printf %s "$dgst_output" | awk -F= '{ print $2 }')
    dgst_value=$(printf %s "$dgst_value" | tr -d '[:space:]')

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

    char="$1"
    shift

    case "$*" in *"$char"*) return 0;; esac; return 1
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

    [ -t 1 ]
}

stderr_isatty() {
    # Check whether stderr is open and refers to a terminal.

    [ -t 2 ]
}

repleat() {
    # Echo repeat replacement character for the width of given value.

    replacement="$1"
    shift

    echo "$@" | tr '[:print:]' "$replacement"
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

    # Three execs, 1 2 3,
    # through comments, one can see,
    # which inline, cannot be.
    #
    #          Use a sh subprocess to support inner printf|sed pipeline.
    #          |       Output leading '.
    #          2       |  Terminate -exec with \;.
    #          |       1  |  Continue find invocation to next line.
    #          |       |  1  |  Path {} from find, wrapped in escaped " quotes.
    #          |       |  |  1  |            Start sed command.
    #          |       |  |  |  2            | Replace ' characters with '\''.
    #          |       |  |  |  |            2 |    Output \ (for \'),
    #          |       |  |  |  |            | 2    escaped three times.
    #          |       |  |  |  |            | |    |          End sed command.
    #          |       1  1  1  |            | |    |          |
    #          2       |  |  |  2            2 2    2          2
    #          |       |  |  |  |            | |    |          |
    find "$path" -type f \
         -exec printf "'" \; \
         -exec sh -c "printf %s \"{}\" | sed \"s/'/'\\\\\\''/g;\"" \; \
         -exec printf "' \\\\\\n" \;
    #                  | |   |
    #                  3 3   3
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
    # Download file at URL.

    DOWNLOAD="$TEMP_DIR"/$PROG.download

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
    #     curl -sSL qwerty.sh | QWERTY_CURL_FLAGS="-v" sh -s - ...

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

        # Support both cases of before and after CLONE_FILEPATH is set.
        if exists "$CLONE_FILEPATH"; then
            quote_argument "$(join_path "$CLONE_FILEPATH" "$repo_file")"
        else
            quote_argument "$repo_file"
        fi

        quote_argument "$(local_filepath "$local_file")"
    done

    # Close array. See `quote_arguments`.
    echo " "
}

validate_repo_filepath() {
    # Check repo filepath and fail with a stderr message if it exists.

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
    # Check local filepath and fail with a stderr message if it exists.

    if [ $# -ne 1 ]; then
        stderr "usage: validate_local_filepath LOCAL_FILE"
        return 2
    fi

    if exists "$FORCE"; then
        return 0
    fi

    local_file="$1"
    shift

    if ! is_stdout "$local_file" && [ -e "$local_file" ]; then
        stderr "$PROG: refusing to overwrite local file: $local_file"
        stderr "(use -f or --force to force overwrite of local files)"
        return 2
    fi
}

validate_filepaths_before_clone() {
    # Validate file paths for writing cloned file(s).
    #
    # Run this before a clone to find errors before attempting download.

    eval "set -- $(iterate_clone_filepaths)"

    cd "$WORKING_DIR"

    if ! exists "$@" && is_stdout "$OUTPUT"; then
        stderr "$PROG: refusing to write entire repository to stdout."
        return 2
    fi

    while [ "$1" != "" ]; do
        repo_file="$1"
        local_file="$2"
        shift 2

        validate_repo_filepath "$repo_file"
        validate_local_filepath "$local_file"
    done
}

clone() {
    # Clone repository, with result at CLONE_FILEPATH.

    given git

    clone_arguments="--depth 1 --single-branch --shallow-submodules"

    if exists "$CLONE_REVISION"; then
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

    # Allow git to generate a humanish directory as default output.
    CLONE_FILEPATH="$PWD/$(ls)"

    rm -fr "$CLONE_FILEPATH/.git"
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
            mv "$CLONE_FILEPATH" "$output"
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
    # Write cloned output according to context.

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

    [ "$@" = "-" ]
}

using_checksum() {
    # Check whether using a checksum in program invocation.

    exists "$MD5$SHA1$SHA224$SHA256$SHA384$SHA512"
}


## Utilities for clean program execution ##

create_temp_dir() {
    # Create temporary directory.

    given mktemp
    TEMP_DIR=$(mktemp)

    # For portability, do not rely on command-line options (i.e. `-d`).
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

parse_arguments() {
    # Parse command-line arguments.
    #
    # All command-line flags must be listed separately,
    # i.e. combined short options in the form of `-abc` are not supported.

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
                -b | --ref | --tag)
                    exists "$CLONE_REVISION" && usage "duplicate ref: $value"
                    CLONE_REVISION="$value"
                    ;;
                --chmod)
                    exists "$CHMOD" && usage "duplicate chmod: $value"
                    CHMOD="$value"
                    ;;
                --md5)
                    exists "$MD5" && usage "duplicate md5: $value"
                    MD5="$value"
                    ;;
                -o | --output)
                    exists "$OUTPUT" && usage "duplicate output: $value"
                    OUTPUT="$value"
                    ;;
                --sha1)
                    exists "$SHA1" && usage "duplicate sha1: $value"
                    SHA1="$value"
                    ;;
                --sha224)
                    exists "$SHA224" && usage "duplicate sha224: $value"
                    SHA224="$value"
                    ;;
                --sha256)
                    exists "$SHA256" && usage "duplicate sha256: $value"
                    SHA256="$value"
                    ;;
                --sha384)
                    exists "$SHA384" && usage "duplicate sha384: $value"
                    SHA384="$value"
                    ;;
                --sha512)
                    exists "$SHA512" && usage "duplicate sha512: $value"
                    SHA512="$value"
                    ;;
                *)
                    eval "set -- $(quote_arguments "$value" "$@")"
                    case "$key" in
                        -f | --force)
                            FORCE=true
                            ;;
                        -h | --help)
                            usage
                            ;;
                        --skip-rej)
                            SKIP_REJ=true
                            ;;
                        -V | --version)
                            version
                            exit
                            ;;
                        *)
                            usage "unrecognized option '$key'"
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

    if using_checksum; then
        if exists "$@"; then
            usage "too many arguments when using a checksum: $@"
        elif exists "$CLONE_REVISION"; then
            usage "invalid repository option in checksum mode: $CLONE_REVISION"
        fi
    fi

    for argument in "$@"; do
        if case "$argument" in "-"*) true;; *) false;; esac; then
            # Argument starts with a hyphen.
            usage "provide options before positional arguments: $argument"
        fi
    done

    if ! exists "$URL"; then
        usage "provide a URL for download."
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

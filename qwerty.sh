#!/usr/bin/env sh
# qwerty.sh: bootstrap repeatable builds with just a keyboard.
#
# Copyright (c) 2018, Ron DuPlain. All rights reserved.
# README: https://github.com/rduplain/qwerty.sh#readme
# Contact: community@qwerty.sh -- See footer for BSD 2-Clause License.

VERSION=0.4-dev

usage() {
    if [ $# -gt 0 ]; then stderr "$PROG: $@"; stderr; fi # Optional message.

    stderr "usage: curl -sSL qwerty.sh      | sh -s - [OPTION...] DOWNLOAD_REF"
    stderr "       curl -sSL qwerty.sh/v0.3 | sh -s - [OPTION...] DOWNLOAD_REF"
    stderr
    stderr "output options:"
    stderr
    stderr "  -o, --output=FILEPATH      Download to this filepath."
    stderr "  --chmod=MODE               Invoke chmod with this upon download."
    stderr
    stderr "checksum options:"
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
    stderr "general options:"
    stderr
    stderr "  -h, --help                 Display this usage message."
    stderr "  -V, --version              Display '$PROG $VERSION' to stdout."
    return 2
}

main() {
    set_traps
    parse_arguments "$@"
    if ! valid_output_exists; then
        download
        checksums_or_rej
        write_output
        remove_temp_download
    fi
    clear_traps
}


## Begin setting global and command-line variables.

# Exit immediately if a command error or non-zero return occurs.
set -e

# Global variables.
PROG=qwerty.sh       # Name of program.
DOWNLOAD=            # Temporary path of downloaded file.

# Variables parsed from command line.
CHMOD=               # Mode invocation for chmod of downloaded file.
DOWNLOAD_REF=        # Reference to download target.
OUTPUT=              # Destination of downloaded file once verified.
SKIP_REJ=            # Skip writing .rej file on failure.

# Checksum values, parsed from command line.
MD5=
SHA1=
SHA224=
SHA256=
SHA384=
SHA512=


## Begin utilities which stand alone without global or command-line variables.

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
            echo "checksum: unknown hash algorithm: $hash_algorithm" >&2
            return 2
            ;;
    esac
}

openssl_dgst() {
    # Print openssl digest value of file checksum to stdout.
    #
    # Unlike `checksum`, this does not validate selection of given algorithm.

    if [ $# -ne 2 ]; then
        stderr "usage: openssl_dgst FILENAME sha1|sha256|..."
        return 2
    fi

    filepath="$1"
    hash_algorithm="$2"
    shift 2

    given openssl
    given awk tr

    dgst_output=$(openssl dgst -$hash_algorithm "$filepath")
    dgst_exit=$?

    if [ $dgst_exit -ne 0 ]; then
        stderr "openssl dgst failed with non-zero status: $dgst_exit"
        return $dsgt_exit
    fi

    # Parse checksum output and trim spaces.
    dgst_value=$(echo "$dgst_output" | awk -F= '{ print $2 }')
    dgst_value=$(echo "$dgst_value" | tr -d '[:space:]')

    if [ -z "$dgst_value" ]; then
        stderr "Unable to parse hash value from openssl dgst call."
        return 3
    fi

    echo $dgst_value
}

stdout_isatty() {
    # Check whether stdout is open and refers to a terminal.

    [ -t 1 ]
}

stderr_isatty() {
    # Check whether stderr is open and refers to a terminal.

    [ -t 2 ]
}

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

repleat() {
    # Echo repeat replacement character for the width of given value.

    replacement="$1"
    shift

    given tr
    echo "$@" | tr '[:print:]' "$replacement"
}

colorize() {
    # Print line to stdout, with given color code, if stderr is a terminal.

    color="$1"
    shift

    if stderr_isatty; then
        printf "\033[1;${color}m%s\033[0m" "$@"
    else
        echo "$@"
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


## Begin tasks which use global and command-line variables.

given() {
    # Check that the given commands exist.

    for command in "$@"; do
        if ! which "$command" > /dev/null; then
            stderr "$PROG requires '$command' command, but cannot find it."
            return 3
        fi
    done
}

valid_output_exists() {
    # Check that the specific output exists and has a valid checksum.

    [ -z "$OUTPUT" ] && return 1 # No output specified.
    [ -e "$OUTPUT" ] || return 1 # No output exists.

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
    # Download as referenced.

    given mktemp
    DOWNLOAD=$(mktemp)

    if [ -d "$DOWNLOAD_REF" ]; then
        stderr "error: $PROG cannot target directories."
        return 2
    elif [ -e "$DOWNLOAD_REF" ]; then
        download_file
    else
        download_url
    fi
}

download_file() {
    # Download a file.

    cp -p "$DOWNLOAD_REF" "$DOWNLOAD"
}

download_url() {
    # Download a URL, passing optional QWERTY_CURL_FLAGS from environment.
    #
    # curl -sSL qwerty.sh | QWERTY_CURL_FLAGS="-v" sh -s - ...

    given curl
    report="--- $(blue $PROG)\n"
    report="${report}Location:\t%{url_effective}\n"
    report="${report}Content-Type:\t%{content_type}\n"
    report="${report}Content-Length:\t%{size_download}\n"
    curl -SL -o "$DOWNLOAD" -w "$report" $QWERTY_CURL_FLAGS "$DOWNLOAD_REF" >&2
}

remove_temp_download() {
    # Remove download.

    rm -f "$DOWNLOAD"
}

checksums_or_rej() {
    # Check all specified checksum values, or write .rej file.

    if checksums; then
        return 0
    else
        status=$?
    fi

    if [ -z "$SKIP_REJ" ]; then
        if [ -z "$OUTPUT" ]; then
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

    if [ -n "$MD5" ]; then
        checksum "${1:-$DOWNLOAD}" md5 "$MD5" || return $?
    fi

    if [ -n "$SHA1" ]; then
        checksum "${1:-$DOWNLOAD}" sha1 "$SHA1" || return $?
    fi

    if [ -n "$SHA224" ]; then
        checksum "${1:-$DOWNLOAD}" sha224 "$SHA224" || return $?
    fi

    if [ -n "$SHA256" ]; then
        checksum "${1:-$DOWNLOAD}" sha256 "$SHA256" || return $?
    fi

    if [ -n "$SHA384" ]; then
        checksum "${1:-$DOWNLOAD}" sha384 "$SHA384" || return $?
    fi

    if [ -n "$SHA512" ]; then
        checksum "${1:-$DOWNLOAD}" sha512 "$SHA512" || return $?
    fi
}

write_output() {
    # Write output given specified parameters.

    if [ -n "$OUTPUT" ]; then
        stderr "Download is valid. Writing to $(green $OUTPUT)."
        mkdir -p "$(dirname "$OUTPUT")"
        cp -p "$DOWNLOAD" "$OUTPUT"
        if [ -n "$CHMOD" ]; then
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

set_traps() {
    # Set shell traps to exit program execution with class.

    trap remove_temp_download INT TERM

    # Set an EXIT trap since ERR is not portable.
    # Be sure to `clear_traps` before exiting on success.
    if stdout_isatty; then
        trap 'remove_temp_download' EXIT
    else
        trap 'stdout "exit $? # Propagate error."; remove_temp_download' EXIT
    fi
}

clear_traps() {
    # Clear shell traps

    trap - INT TERM EXIT
}

version() {
    # Print version to stdout.

    stdout $PROG $VERSION
}

parse_arguments() {
    # Parse command-line arguments.

    given awk

    while [ "$1" != "" ]; do
        if case $1 in "-"*) true;; *) false;; esac; then
            # Argument starts with a hyphen.
            key=$(echo "$1" | awk -F= '{ print $1 }')
            value=$(echo "$1" | awk -F= '{ print $2 }')
            shift
            if [ -z "$value" ]; then
                value="$1"
                [ -n "$value" ] && shift
            fi
            case "$key" in
                --chmod)
                    [ -n "$CHMOD" ] && usage "duplicate chmod"
                    CHMOD="$value"
                    ;;
                --md5)
                    [ -n "$MD5" ] && usage "duplicate md5"
                    MD5="$value"
                    ;;
                -o | --output)
                    [ -n "$OUTPUT" ] && usage "duplicate output"
                    OUTPUT="$value"
                    ;;
                --sha1)
                    [ -n "$SHA1" ] && usage "duplicate sha1"
                    SHA1="$value"
                    ;;
                --sha224)
                    [ -n "$SHA224" ] && usage "duplicate sha224"
                    SHA224="$value"
                    ;;
                --sha256)
                    [ -n "$SHA256" ] && usage "duplicate sha256"
                    SHA256="$value"
                    ;;
                --sha384)
                    [ -n "$SHA384" ] && usage "duplicate sha384"
                    SHA384="$value"
                    ;;
                --sha512)
                    [ -n "$SHA512" ] && usage "duplicate sha512"
                    SHA512="$value"
                    ;;
                *)
                    set -- "$value" "$@"
                    case "$key" in
                        -h | --help)
                            usage
                            ;;
                        --skip-rej)
                            [ -n "$SKIP_REJ" ] && usage "duplicate skip-rej"
                            SKIP_REJ=true
                            ;;
                        -V | --version)
                            version
                            exit
                            ;;
                        *)
                            usage "$PROG: unrecognized option '$key'"
                            ;;
                    esac
                    ;;
            esac
        else
            # Argument does NOT start with a hyphen.
            [ -n "$DOWNLOAD_REF" ] && usage "too many arguments at '$1'"
            DOWNLOAD_REF="$1"
            shift
        fi
    done

    if [ -z "$MD5$SHA1$SHA224$SHA256$SHA384$SHA512" ]; then
        usage "provide a checksum value e.g. --sha256=..."
    fi
}


## Begin program execution.

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

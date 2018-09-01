#!/usr/bin/env sh
# qwerty.sh v0.3-dev: download reliably when all you have is a keyboard.
#
# Copyright (c) 2018, Ron DuPlain. All rights reserved.
# Contact: community@qwerty.sh -- See footer for BSD 2-Clause License.

usage() {
    if [ $# -gt 0 ]; then stderr "$@"; stderr; fi # Print arguments if given.

    # curl -sSL qwerty.sh | sh -s - [OPTION...] DOWNLOAD_REF
    stderr "usage: $PROG [OPTION...] DOWNLOAD_REF"
    stderr
    stderr "output options:"
    stderr
    stderr "  --output=FILEPATH          Download to this filepath."
    stderr "  --chmod=MODE               Invoke chmod with this upon download."
    stderr
    stderr "checksum options:"
    stderr
    stderr "  --md5=..."
    stderr "  --sha1=..."
    stderr "  --sha224=..."
    stderr "  --sha256=..."
    stderr "  --sha384=..."
    stderr "  --sha512=..."
    return 2
}

# Exit immediately if a command error or non-zero return occurs.
set -e

# Global variables.
PROG=qwerty.sh       # Name of program.
DOWNLOAD=''          # Temporary path of downloaded file.

# Variables parsed from command line.
CHMOD=''             # Mode invocation for chmod of downloaded file.
DOWNLOAD_REF=''      # Reference to download target.
OUTPUT=''            # Destination of downloaded file once verified.

# Checksum values, parsed from command line.
MD5=
SHA1=
SHA224=
SHA256=
SHA384=
SHA512=

download() {
    # Download as referenced.

    if [ $# -ne 1 ]; then
        stderr "usage: download REF"
        return 2
    fi

    ref="$1"
    shift 1

    given mktemp
    DOWNLOAD=$(mktemp)

    if [ -d "$ref" ]; then
        stderr "error: $PROG cannot target directories."
        return 2
    elif [ -e "$ref" ]; then
        download_file "$ref"
    else
        download_url "$ref"
    fi
}

download_file() {
    # Download a file.

    cp -p "$1" "$DOWNLOAD"
}

download_url() {
    # Download a URL.

    given curl
    curl -SL -o "$DOWNLOAD" "$1"
}

remove_download() {
    # Remove download.

    rm -f "$DOWNLOAD"
}

checksums() {
    # Check all specified checksum values.

    if [ $# -ne 1 ]; then
        stderr "usage: checksums FILENAME"
        return 2
    fi

    filepath="$1"
    shift

    if [ -n "$MD5" ]; then
        checksum "$filepath" md5 "$MD5"
    fi

    if [ -n "$SHA1" ]; then
        checksum "$filepath" sha1 "$SHA1"
    fi

    if [ -n "$SHA224" ]; then
        checksum "$filepath" sha224 "$SHA224"
    fi

    if [ -n "$SHA256" ]; then
        checksum "$filepath" sha256 "$SHA256"
    fi

    if [ -n "$SHA384" ]; then
        checksum "$filepath" sha384 "$SHA384"
    fi

    if [ -n "$SHA512" ]; then
        checksum "$filepath" sha512 "$SHA512"
    fi
}

checksum() {
    # Verify checksum of file, exiting non-zero if hash does not match.

    if [ $# -ne 3 ]; then
        stderr "usage: checksum FILENAME sha1|sha256|... HASH"
        return 2
    fi

    local filepath="$1"
    local hash_function=$2
    local hash_value=$3
    shift 3

    given openssl
    given awk tr

    case "$hash_function" in
        "sha1" | "sha224" | "sha256" | "sha384" | "sha512" | "md5" )
            dgst_output=$( openssl dgst -$hash_function "$filepath" )
            dgst_exit=$?

            if [ $dgst_exit -ne 0 ]; then
                stderr "dgst failed with non-zero status: $dgst_exit"
                return $dsgt_exit
            fi

            # Parse checksum output and trim spaces.
            dgst_value=$(echo "$dgst_output" | awk -F= '{ print $2 }')
            dgst_value=$(echo "$dgst_value" | tr -d '[:space:]')

            if [ -z "dgst_value" ]; then
                stderr "Unable to parse hash value from openssl dgst call."
                return 3
            fi

            stderr "$hash_function: $dgst_value"

            if [ "$hash_value" != "$dgst_value" ]; then
                stderr "$hash_function mismatch: $hash_value"
                return 1
            fi
            ;;
        * )
            echo "checksum: unknown hash function: $hash_function" >&2
            return 2
            ;;
    esac
}

write_output() {
    # Write output given specified parameters.

    if [ -n "$OUTPUT" ]; then
        mkdir -p "$(dirname "$OUTPUT")"
        cp -p "$DOWNLOAD" "$OUTPUT"
        if [ -n "$CHMOD" ]; then
            chmod "$CHMOD" "$OUTPUT"
        fi
    fi
}

isatty() {
    # Check whether stdout is open and refers to a terminal.

    [ -t 1 ]
}

given() {
    # Check that the given commands exist.

    for command in "$@"; do
        if ! which "$command" > /dev/null; then
            stderr "$PROG requires '$command' command, but cannot find it."
            return 3
        fi
    done
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

set_traps() {
    # Set shell traps to exit program execution with class.

    trap remove_download INT TERM

    # Set an EXIT trap since ERR is not portable.
    # Be sure to `clear_traps` before exiting on success.
    if isatty; then
        trap 'remove_download' EXIT
    else
        trap 'remove_download; stdout "exit 1 # Propagate error."' EXIT
    fi
}

clear_traps() {
    # Clear shell traps

    trap - INT TERM EXIT
}

parse_arguments() {
    # Parse command-line arguments.

    given awk

    while [ "$1" != "" ]; do
        if case $1 in "-"*) true;; *) false;; esac; then
            # Argument starts with a hyphen.
            key=$(echo "$1" | awk -F= '{ print $1 }')
            value=$(echo "$1" | awk -F= '{ print $2 }')
            case "$key" in
                -h | --help)
                    usage
                    ;;
                --chmod)
                    CHMOD="$value"
                    ;;
                --md5)
                    MD5="$value"
                    ;;
                --output)
                    OUTPUT="$value"
                    ;;
                --sha1)
                    SHA1="$value"
                    ;;
                --sha224)
                    SHA224="$value"
                    ;;
                --sha256)
                    SHA256="$value"
                    ;;
                --sha384)
                    SHA384="$value"
                    ;;
                --sha512)
                    SHA512="$value"
                    ;;
                *)
                    stderr "$PROG: unknown option '$1'"
                    usage
                    ;;
            esac
        else
            # Argument does NOT start with a hyphen.
            if [ -n "$DOWNLOAD_REF" ]; then
                usage
            else
                DOWNLOAD_REF="$1"
            fi
        fi
        shift
    done
}

main() {
    # The main routine of qwerty.sh.

    set_traps
    parse_arguments "$@"

    download "$DOWNLOAD_REF"
    checksums "$DOWNLOAD"

    if ! isatty && [ -z "$OUTPUT" ]; then
        cat "$DOWNLOAD"
    fi

    write_output

    remove_download
    clear_traps
}

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

"""https_qwerty.py: serve qwerty.sh file as requested."""

import os
import re
import shutil
import subprocess

from wsgi_qwerty import bytes_response, create_application, string_response


DIRTY = 'DIRTY'

SHELL_BAD_REQUEST = """
#!/bin/sh
echo "qwerty.sh: bad request." >&2

exit 40
""".strip() + '\n'

SHELL_NOT_FOUND = """
#!/bin/sh
echo "qwerty.sh: revision '{}' not found." >&2

exit 44
""".strip() + '\n'

VALID_REQUEST = re.compile('^[a-zA-Z0-9\-\.]*$')


def serve_qwerty(environ):
    """Serve qwerty.sh file as requested.

    URL path indicates git ref to serve, defaulting to current HEAD.
    Example:

        https://qwerty.sh/c0ffee # => serve qwerty.sh at ref c0ffee
    """
    if not valid_request(environ):
        return (
            # HTTP Status
            '400 BAD REQUEST',

            # HTTP Response Headers
            (('Content-Type', 'text/plain'),),

            # WSGI Body
            string_response(SHELL_BAD_REQUEST))

    req_ref = parse_ref(environ.get('PATH_INFO', '/'))
    ref = resolve_ref(req_ref)

    if ref is None:
        return (
            # HTTP Status
            '404 NOT FOUND',

            # HTTP Response Headers
            (('Content-Type', 'text/plain'),),

            # WSGI Body
            string_response(SHELL_NOT_FOUND.format(req_ref)))
    else:
        return (
            # HTTP Status
            '200 OK',

            # HTTP Response Headers
            (('Content-Type', 'text/plain'),),

            # WSGI Body
            bytes_response(git_show(ref, 'qwerty.sh', return_bytes=True)))


application = create_application(serve_qwerty)


def resolve_ref(ref):
    """Resolve to an exact ref, else None."""
    if ref == DIRTY:
        return ref
    try:
        return git_rev_parse(ref)
    except CommandFailure:
        for remote in git_remote():
            try:
                return git_rev_parse('{remote}/{ref}'.format(**locals()))
            except CommandFailure:
                continue
        return None


def parse_ref(url_path):
    """Parse URL which has a git ref."""
    ref = url_path.lstrip('/')
    if not ref:
        ref = os.environ.get('DEFAULT_GIT_REF', 'HEAD').strip()
    return ref


def valid_request(environ):
    """True if request is valid, else False."""
    if environ.get('REQUEST_METHOD') != 'GET':
        return False
    if environ.get('QUERY_STRING'):
        return False
    requested = environ.get('PATH_INFO', '/').lstrip('/')
    if not requested:
        return True
    if len(requested) > 40: # Larger than git SHA reference.
        return False
    if VALID_REQUEST.match(requested) is None:
        return False
    return True


def git_remote(**kw):
    """List of remote names as returned by `git remote`."""
    return sh('git', 'remote', **kw).strip().split('\n')


def git_rev_parse(ref, **kw):
    """Run `git rev-parse --short` on given ref, return stdout."""
    return sh('git', 'rev-parse', '--short', ref, **kw).strip()


def git_show(ref, filepath, **kw):
    """Provide file content at given ref (via `git show`).

    Accept a project-specific ref 'DIRTY' which requests file content within
    the working tree, whether the file matches HEAD or is modified/dirty. When
    GIT_DIR is in use, the working tree may not be known. Therefore, an
    environment variable QWERTY_SH specifies where to find the qwerty.sh file.

    Note: 'DIRTY' is useful for development and not intended for production.
    """
    if ref == DIRTY and filepath == 'qwerty.sh':
        return sh('cat', os.environ.get('QWERTY_SH', filepath), **kw)
    return sh('git', 'show', '{ref}:{filepath}'.format(**locals()), **kw)


def sh(*args, return_bytes=False, encoding='utf-8', **kw):
    """Run shell command, returning stdout. Raise error on non-zero exit."""
    options = dict(
        stderr=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    options.update(kw)

    process = subprocess.Popen(args, **options)
    process.wait()

    if process.returncode != 0:
        raise CommandFailure(process.stderr.read().decode(encoding))

    if return_bytes:
        return process.stdout.read()

    return process.stdout.read().decode(encoding)


class CommandFailure(subprocess.SubprocessError):
    """A command failed."""


def flight_check():
    commands = ['git']
    for command in commands:
        if shutil.which(command) is None:
            raise RuntimeError('command not found: {}'.format(command))

    git_rev_parse('HEAD')


flight_check()


if __name__ == '__main__':
    from wsgi_qwerty import run_main

    run_main(application)

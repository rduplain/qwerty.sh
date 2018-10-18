"""https_qwerty.py: serve qwerty.sh file as requested."""

import shutil
import subprocess

from wsgi_qwerty import string_response


SHELL_NOT_FOUND = """
#!/usr/bin/env sh
echo "qwerty.sh: revision '{}' not found."  >&2

exit 2
""".strip() + '\n'


def application(environ, start_response):
    """WSGI callable to serve qwerty.sh file as requested.

    URL path indicates git ref to serve, defaulting to current HEAD.
    Example:

        https://qwerty.sh/c0ffee # => serve qwerty.sh at ref c0ffee
    """
    req_ref = parse_ref(environ.get('PATH_INFO', '/'))
    ref = resolve_ref(req_ref)

    if ref is None:
        start_response(
            # HTTP Status
            '404 NOT FOUND',

            # HTTP Response Headers
            (('Content-Type', 'text/plain'),))

        return string_response(SHELL_NOT_FOUND.format(req_ref))
    else:
        start_response(
            # HTTP Status
            '200 OK',

            # HTTP Response Headers
            (('Content-Type', 'text/plain'),))

        return string_response(git_show(ref, 'qwerty.sh'))


def resolve_ref(ref):
    """Resolve to an exact ref, else None."""
    try:
        return git_rev_parse(ref)
    except CommandFailure:
        for remote in git_remote():
            try:
                return git_rev_parse(f'{remote}/{ref}')
            except CommandFailure:
                continue
        return None


def parse_ref(url_path):
    """Parse URL which has a git ref."""
    ref = url_path.lstrip('/')
    if not ref:
        ref = 'HEAD'
    return ref


def git_remote():
    """List of remote names as returned by `git remote`."""
    return sh('git', 'remote').strip().split('\n')


def git_rev_parse(ref):
    """Run `git rev-parse --short` on given ref, return stdout."""
    return sh('git', 'rev-parse', '--short', ref).strip()


def git_show(ref, filepath):
    """Provide file content at given ref (via `git show`)."""
    return sh('git', 'show', f'{ref}:{filepath}')


def sh(*args, **kw):
    """Run shell command, returning stdout. Raise error on non-zero exit."""
    options = dict(
        encoding='utf-8',
        stderr=subprocess.PIPE,
        stdout=subprocess.PIPE,
    )
    options.update(kw)

    process = subprocess.run(args, **options)

    if process.returncode != 0:
        raise CommandFailure(process)

    return process.stdout


class CommandFailure(subprocess.SubprocessError):
    """A command failed."""

    def __init__(self, completed_process):
        super().__init__(completed_process.stderr)


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

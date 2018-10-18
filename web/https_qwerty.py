"""https_qwerty.py: serve qwerty.sh file as requested."""

from wsgi_qwerty import string_response


SHELL_REDIRECT = """
#!/usr/bin/env sh
echo 'error: Use `-L` to support redirects.'  >&2
echo                                          >&2
echo 'curl -sSL qwerty.sh'                    >&2

exit 2
""".strip() + '\n'


def parse_ref(url_path):
    """Parse URL which has a git ref."""
    ref = url_path.lstrip('/')
    if not ref:
        ref = 'master'
    return ref


def github(ref, username='rduplain', domain='raw.githubusercontent.com'):
    """Build URL for GitHub location of raw qwerty.sh file matching git ref."""
    return f'https://{domain}/{username}/qwerty.sh/{ref}/qwerty.sh'


def application(environ, start_response):
    """WSGI callable to serve qwerty.sh file as requested.

    URL path indicates git ref to serve, defaulting to 'master'.
    Example:

        https://qwerty.sh/c0ffee # => serve qwerty.sh at ref c0ffee
    """
    ref = parse_ref(environ.get('PATH_INFO', '/'))

    start_response(
        # HTTP Status
        '301 MOVED PERMANENTLY',

        # HTTP Response Headers
        (('Content-Type', 'text/plain'),
         ('Location', github(ref))))

    return string_response(SHELL_REDIRECT)


if __name__ == '__main__':
    from wsgi_qwerty import run_main

    run_main(application)

"""http_qwerty.py: redirect HTTP to HTTPS with a meaningful response body."""

from urllib.parse import urlparse, urlunparse


SHELL_REDIRECT = """
#!/usr/bin/env sh
echo 'error: Use HTTPS.'     >&2
echo                         >&2
echo 'curl -sSL qwerty.sh'   >&2

exit 2
""".strip() + '\n'

HTTPS_LOCATION = 'https://qwerty.sh/'


def string_response(s, encoding='utf-8'):
    """Convert string to WSGI string response."""
    return [bytes(line, encoding) for line in s.splitlines(keepends=True)]


def application(environ, start_response, redirect_to=HTTPS_LOCATION):
    # Preserve path information and query string in redirect.
    location_parts = urlparse(redirect_to)._replace(
        path=environ['PATH_INFO'],
        query=environ['QUERY_STRING'])

    start_response(
        '301 MOVED PERMANENTLY',
        (('Content-Type', 'text/plain'),
         ('Location', urlunparse(location_parts))))

    return string_response(SHELL_REDIRECT)


def run_development(app, host='localhost', port=8000, **kw):
    from werkzeug.serving import run_simple
    kw['use_reloader'] = kw.get('use_reloader', True)
    run_simple(host, port, app, **kw)


if __name__ == '__main__':
    run_development(application)

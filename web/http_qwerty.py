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


def https_location(environ, redirect_to):
    """Build URL for redirect to location which preserves path & query."""
    location_parts = urlparse(redirect_to)._replace(
        path=environ['PATH_INFO'],
        query=environ['QUERY_STRING'])

    return urlunparse(location_parts)


def application(environ, start_response, redirect_to=HTTPS_LOCATION):
    """WSGI callable to redirect all requests to HTTPS location."""
    start_response(
        '301 MOVED PERMANENTLY',
        (('Content-Type', 'text/plain'),
         ('Location', https_location(environ, redirect_to))))

    return string_response(SHELL_REDIRECT)


def run_development(app, host='localhost', port=8000, **kw):
    """Run a WSGI development server."""
    from werkzeug.serving import run_simple

    kw['use_reloader'] = kw.get('use_reloader', True)
    run_simple(host, port, app, **kw)


if __name__ == '__main__':
    run_development(application)

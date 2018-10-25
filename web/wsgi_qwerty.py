"""wsgi_qwerty.py: WSGI utilities for qwerty.sh project."""

import logging
from urllib.parse import urlparse, urlunparse


SHELL_SERVER_ERROR = """
#!/usr/bin/env sh
echo "qwerty.sh: internal server error."  >&2

exit 50
""".strip() + '\n'


logger = logging.getLogger()
logger.addHandler(logging.StreamHandler())
logger.setLevel(logging.INFO)


def bytes_response(b):
    """Prepare bytes as WSGI response."""
    return [b]


def create_application(fn):
    """Create WSGI callable which wraps given fn."""

    def application(environ, start_response):
        """WSGI callable."""
        try:
            http_status, http_headers, wsgi_body = fn(environ)
        except Exception:
            logger.exception('---')
            return error_response(environ, start_response)

        start_response(http_status, http_headers)
        return wsgi_body

    return application


def error_response(environ, start_response, response=None):
    """Start and return an error response."""
    start_response(
        # HTTP Status
        '500 INTERNAL SERVER ERROR',

        # HTTP Response Headers
        (('Content-Type', 'text/plain'),))

    if response is None:
        return string_response(SHELL_SERVER_ERROR)

    return response


def https_location(environ, redirect_to):
    """Build URL for redirect to location which preserves path & query."""
    location_parts = urlparse(redirect_to)._replace(
        path=environ['PATH_INFO'],
        query=environ['QUERY_STRING'])

    return urlunparse(location_parts)


def run_development(app, host='localhost', port=8000, **kw):
    """Run a WSGI development server."""
    from werkzeug.serving import run_simple

    kw['use_reloader'] = kw.get('use_reloader', True)
    run_simple(host, port, app, **kw)


def run_main(app):
    """Run a WSGI development server, using port given on command line."""
    from sys import argv

    kw = {}
    if len(argv) > 1:
        kw['port'] = int(argv[1])
    run_development(app, **kw)


def string_response(s, encoding='utf-8'):
    """Convert string to WSGI string response."""
    return [bytes(s, encoding)]

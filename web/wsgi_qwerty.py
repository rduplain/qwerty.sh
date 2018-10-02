"""wsgi_qwerty.py: WSGI utilities for qwerty.sh project."""

from urllib.parse import urlparse, urlunparse


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


def string_response(s, encoding='utf-8'):
    """Convert string to WSGI string response."""
    return [bytes(s, encoding)]

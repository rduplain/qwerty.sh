"""http_qwerty.py: redirect HTTP to HTTPS with a meaningful response body."""

import os

from wsgi_qwerty import create_application, https_location, string_response


SHELL_REDIRECT = """
#!/usr/bin/env sh
echo 'error: Use HTTPS.'     >&2
echo                         >&2
echo 'curl -sSL qwerty.sh'   >&2

exit 2
""".strip() + '\n'

HTTPS_LOCATION = os.environ.get('QWERTY_HTTPS_LOCATION', 'https://qwerty.sh/')


def redirect_to_https(environ):
    """Redirect all requests to HTTPS location."""
    return (
        # HTTP Status
        '301 MOVED PERMANENTLY',

        # HTTP Response Headers
        (('Content-Type', 'text/plain'),
         ('Location', https_location(environ, HTTPS_LOCATION))),

        # WSGI Body
        string_response(SHELL_REDIRECT))


application = create_application(redirect_to_https)


if __name__ == '__main__':
    from wsgi_qwerty import run_main

    run_main(application)

"""http_qwerty.py: redirect HTTP to HTTPS with a meaningful response body."""

from wsgi_qwerty import https_location, string_response


SHELL_REDIRECT = """
#!/usr/bin/env sh
echo 'error: Use HTTPS.'     >&2
echo                         >&2
echo 'curl -sSL qwerty.sh'   >&2

exit 2
""".strip() + '\n'

HTTPS_LOCATION = 'https://qwerty.sh/'


def application(environ, start_response, redirect_to=HTTPS_LOCATION):
    """WSGI callable to redirect all requests to HTTPS location."""
    start_response(
        # HTTP Status
        '301 MOVED PERMANENTLY',

        # HTTP Response Headers
        (('Content-Type', 'text/plain'),
         ('Location', https_location(environ, redirect_to))))

    return string_response(SHELL_REDIRECT)


if __name__ == '__main__':
    from wsgi_qwerty import run_development

    run_development(application)

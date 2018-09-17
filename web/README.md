## web: serve qwerty.sh script via HTTPS (redirecting HTTP)

### HTTP

Redirect HTTP requests to HTTPS. Provide a custom redirect response, such that
curl provides a meaningful error response when the `-L` redirect flag is not
provided.

```sh
curl qwerty.sh      # Shows a meaningful error and exits non-zero.
curl -sSL qwerty.sh # Redirects to https://qwerty.sh.
```

### HTTPS

By default, serve up the latest release of the qwerty.sh shell script.

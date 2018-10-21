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
Support downloading a specific version or git reference:

```sh
curl -sSL qwerty.sh/v0.3
curl -sSL qwerty.sh/ab4f960
```


### Development

Run:

```sh
make run
```

Test:

```sh
curl -sSL localhost:8001/v0.3 | head
```

## web: serve qwerty.sh script via HTTPS (redirecting HTTP)

### Requirements

* All HTTP responses shall redirect to the HTTPS location of the same path.
* HTTPS shall be terminated by a proxying httpd.
* All HTTP and HTTPS responses shall have a shell body:
  1. 200 OK -- Only when serving the qwerty.sh file itself.
  2. 301 MOVED PERMANENTLY
  3. 404 NOT FOUND
  4. 500 INTERNAL SERVER ERROR
  5. 502 BAD GATEWAY -- Loaded separately as a static file in proxying httpd.
* Each non-200 shell body shall be meaningful with error and exit code.
* Each shell body shall expect the user to pipe it into `sh`.
* Minimize overhead and response time of web services.
* Minimize dependencies as to allow for simple self-hosting of web services.
* Expose configuration variables.
* It is okay to hardcode "qwerty.sh" as to have shell code be self-documenting.


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

Support Python 3.4+.

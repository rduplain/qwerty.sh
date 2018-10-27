## web: serve qwerty.sh script via HTTPS (redirecting HTTP)

### Requirements

* All HTTP responses shall redirect to the HTTPS location of the same path.
* HTTPS shall be terminated by a proxying httpd.
* All HTTP and HTTPS responses shall have a shell body:
  1. 200 OK -- Only when serving the qwerty.sh file itself.
  1. 301 MOVED PERMANENTLY
  1. 404 NOT FOUND
  1. 500 INTERNAL SERVER ERROR
  1. 502 BAD GATEWAY -- Loaded separately as a static file in proxying httpd.
* Each non-200 shell body shall be meaningful with error and exit code.
* Each shell body shall expect the user to pipe it into `sh`.
* Minimize overhead and response time of web services.
* Minimize dependencies as to allow for simple self-hosting of web services.
* Expose configuration variables.
* It is okay to hardcode "qwerty.sh" as to have shell code be self-documenting.


### Python

Support Python 3.4+.


### HTTP

Redirect HTTP requests to HTTPS.

```sh
curl qwerty.sh                 # Show a meaningful error and exit non-zero.
curl -sSL qwerty.sh            # Redirect to https://qwerty.sh.
```


### HTTPS

By default, serve the latest release of the qwerty.sh shell script.

```sh
curl -sSL qwerty.sh
```

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
curl -sSL localhost:8001 | sh -s - --help
curl -sSL localhost:8001 | head
curl -sSL localhost:8001/v0.3 | head
```


### Production

See: [Configuration files for qwerty.sh deployment on a single server.][config]

Clone the qwerty.sh repository and checkout the default version to serve.
Prepare:

```sh
make install
```

Use a process manager to run these, setting WORKERS based on number of CPUs:

```sh
WORKERS=4 PORT=8001 make http-proxied
WORKERS=4 PORT=8002 make https-proxied
```

Use an industrial httpd to proxy:

* port 80 to 8001
* port 443 to 8002

The strength of qwerty.sh depends on the HTTPS implementation.


[config]: https://gist.github.com/rduplain/3727fbd58d2a0066f2f447ac094f93d7

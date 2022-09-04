## qwerty.sh: download, verify, unpack files in a single, portable command.

[qwerty.sh](https://qwerty.sh) is a script as a service.
On any Unix shell with `curl` available:

```sh
Q=https://raw.githubusercontent.com/rduplain/qwerty.sh/v0.8/qwerty.sh
alias qwerty.sh="curl --proto '=https' --tlsv1.2 -sSf $Q | Q=$Q sh -s -"
```

Without any installation, the `qwerty.sh` command acts like any other program
on the PATH. Use it to bootstrap downloads from git repositories or the web.

Execute [a file][hello.sh] downloaded with `git`:

```sh
qwerty.sh https://github.com/rduplain/qwerty.sh.git web/hello/hello.sh:- | sh
```

Execute [a file][hello.sh], but only if it matches a predetermined checksum:

```sh
qwerty.sh \
  --sha256=87d9aaac491de41f2e19d7bc8b3af20a54645920c499bbf868cd62aa4a77f4c7 \
  http://hello.qwerty.sh | sh
```

`qwerty.sh` uses whatever `curl`, `git`, and `openssl` commands it finds.

---

[Reference](doc/reference.md).

Contact: community@qwerty.sh

Copyright (c) 2018-2022, R. DuPlain. All rights reserved.
BSD 2-Clause License.

... with apologies to Dvorak.


[hello.sh]: https://github.com/rduplain/qwerty.sh/blob/master/web/hello/hello.sh

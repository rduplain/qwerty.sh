## qwerty.sh: download reliably when all you have is a keyboard.

How do you verify integrity of a downloaded file, when the download installs
the very tool that you need to bootstrap a build process? Too often, you
don't. Installation instructions commonly pipe the output of `curl` into `sh`,
sometimes leading to blind `sudo` password prompts, and archive files often
download over plaintext internet connections without a checksum or signature.

Express yourself against the status quo with command-line poetry:

```sh
curl -sSL qwerty.sh |\
  sh -s - \
  --sha256=5438dc18c98158c56bc6567c13dbfb0276a6ac96e5f721fc2f986278534b28e0 \
  http://hello.qwerty.sh | sh
```

Download a file:

```sh
curl -sSL qwerty.sh |\
  sh -s - \
  --sha256=5438dc18c98158c56bc6567c13dbfb0276a6ac96e5f721fc2f986278534b28e0 \
  --output=hello --chmod=a+x \
  http://hello.qwerty.sh
```

The qwerty.sh project provides fully portable shell with checksum support using
commands commonly found on Unix platforms, and makes every effort to provide
simple error messages when things go wrong. All of this together provides a
means to publish executable checksum specifications.

Status: Alpha; consider the project a prototype until the v1.0 release.

... with apologies to Dvorak.

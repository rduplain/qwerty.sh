run: Procfile | poorman-command python-command lint
	$(POORMAN) start

%-gunicorn: python-command
	@$(PYTHON_ENV)/bin/gunicorn \
		--bind 127.0.0.1:$(PORT) \
		--workers $(WORKERS) \
		--access-logfile - \
		$*_qwerty:application

http-proxied: http-gunicorn
https-proxied: https-gunicorn

python-repl: python-command
	$(PYTHON)

lint: python-command
	@$(PYTHON_ENV)/bin/pyflakes *.py

PYTHON_REQUIREMENTS := gunicorn==19.9.0 pyflakes werkzeug==0.14.1

# Indicate to python.mk that requirements are specified in _this_ Makefile.
PYTHON_REQUIREMENTS_MAKEFILE := $(lastword $(MAKEFILE_LIST))

include .Makefile.d-init.mk
include .Makefile.d/path.mk
include .Makefile.d/poorman.mk
include .Makefile.d/procfile.mk
include .Makefile.d/python.mk

Procfile: proc proc-http-dev proc-https-dev
.PHONY: Procfile

run-%-dev:
	$(PYTHON) $*_qwerty.py $(PORT)

run-http-dev:  PORT := 8001
run-https-dev: PORT := 8002

run-http-dev:  export QWERTY_HTTPS_LOCATION := http://localhost:8002/

# Configuration supported via environment variables.

ifeq ($(GIT_DIR),)
export GIT_DIR := $(abspath $(dir $(PROJECT_ROOT)))/.git
endif

ifeq ($(WORKERS),)
WORKERS := 2
endif

ifeq ($(PORT),)
PORT := 8080
endif

run: lint python-command
	$(PYTHON) http_qwerty.py

http-proxied: python-command
	@$(PYTHON_ENV)/bin/gunicorn \
		--bind 127.0.0.1:$(PORT) \
		--workers $(WORKERS) \
		--access-logfile - \
		http_qwerty:application

python-repl: python-command
	$(PYTHON)

lint: python-command
	@$(PYTHON_ENV)/bin/pyflakes *.py

PYTHON_REQUIREMENTS := gunicorn==19.9.0 pyflakes werkzeug==0.14.1

# Indicate to python.mk that requirements are specified in _this_ Makefile.
PYTHON_REQUIREMENTS_MAKEFILE := $(lastword $(MAKEFILE_LIST))

include .Makefile.d-init.mk
include .Makefile.d/python.mk

# Configuration supported via environment variables.

ifeq ($(WORKERS),)
WORKERS := 2
endif

ifeq ($(PORT),)
PORT := 8080
endif

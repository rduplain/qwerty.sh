run: lint python-command
	$(PYTHON) http_qwerty.py

python-repl: python-command
	$(PYTHON)

lint: python-command
	@$(PYTHON_ENV)/bin/pyflakes *.py

PYTHON_REQUIREMENTS := pyflakes werkzeug==0.14.1

# Indicate to python.mk that requirements are specified in _this_ Makefile.
PYTHON_REQUIREMENTS_MAKEFILE := $(lastword $(MAKEFILE_LIST))

include .Makefile.d-init.mk
include .Makefile.d/python.mk

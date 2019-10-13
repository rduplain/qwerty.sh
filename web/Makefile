### Development ###

all: lint

# To run the development server beyond localhost: `HOST=0.0.0.0 make run`.
run: Procfile | poorman-command install lint
	$(POORMAN) start

python-repl: python-command
	$(PYTHON)

lint: python-command
	@$(PYTHON_ENV)/bin/pyflakes *.py


### Production ###

install: python-command

%-gunicorn: python-command
	@mkdir -p $(REQD_VAR)/run
	@$(PYTHON_ENV)/bin/gunicorn \
		--pid $(REQD_VAR)/run/$@.pid \
		--bind 127.0.0.1:$(PORT) \
		--workers $(WORKERS) \
		--access-logfile - \
		--access-logformat $(GUNICORN_ACCESS_LOGFORMAT) \
		$*_qwerty:application

GUNICORN_ACCESS_LOGFORMAT := \
 '%({x-forwarded-for}i)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s"'

http-proxied: http-gunicorn
https-proxied: https-gunicorn

deploy:
	git push origin master; true
	git push --tags origin
	ssh qwerty.sh ' \
		set -e; \
		export PATH=/usr/local/bin:/usr/bin:/bin; \
		hostname; \
		uptime; \
		cd /srv/qwerty.sh; \
		git remote update; \
		git reset --hard HEAD; \
		git checkout $(VERSION); \
		make --no-print-directory install; \
		supervisorctl status http-qwerty https-qwerty; \
		echo "Starting/Reloading qwerty.sh web services ..."; \
		supervisorctl start http-qwerty https-qwerty >/dev/null 2>&1 || true; \
		sudo -n kill -HUP `cat /srv/qwerty.sh/web/.reqd/var/run/*.pid`; \
		supervisorctl status http-qwerty https-qwerty; \
		date'
	curl -sSL qwerty.sh | sh -s - --version

deploy: VERSION := $(shell git describe --tags --abbrev=0)

# A restart is only needed on changes to Python env or gunicorn settings.
deploy-restart: | deploy
	ssh qwerty.sh ' \
		set -e; \
		export PATH=/usr/local/bin:/usr/bin:/bin; \
		hostname; \
		supervisorctl restart http-qwerty https-qwerty; \
		supervisorctl status http-qwerty https-qwerty'
	curl -sSL qwerty.sh | sh -s - --version

## Configuration supported via environment variables. ##

ifeq ($(WORKERS),)
WORKERS := 2
endif

ifeq ($(PORT),)
PORT := 8080
endif


### External Dependencies ###

PYTHON_REQUIREMENTS := gunicorn==19.9.0 pyflakes werkzeug==0.14.1


### Implementation Details ###

# Indicate to python.mk that requirements are specified in _this_ Makefile.
PYTHON_REQUIREMENTS_MAKEFILE := $(lastword $(MAKEFILE_LIST))

include .Makefile.d-init.mk
include .Makefile.d/path.mk
include .Makefile.d/poorman.mk
include .Makefile.d/procfile.mk
include .Makefile.d/python.mk
include .Makefile.d/reqd.mk

PARENT_PROJECT_ROOT := $(abspath $(dir $(PROJECT_ROOT)))

Procfile: proc proc-http-dev proc-https-dev
.PHONY: Procfile

run-%-dev:
	$(PYTHON) $*_qwerty.py $(PORT)

run-http-dev:  PORT := 8001
run-https-dev: PORT := 8002

ifeq ($(HOST),)
run-http-dev:  export QWERTY_HTTPS_LOCATION := http://localhost:8002/
else
run-http-dev:  export QWERTY_HTTPS_LOCATION := http://$(shell hostname):8002/
endif

run-https-dev: export DEFAULT_GIT_REF := DIRTY # DIRTY is a made-up ref.
run-https-dev: export QWERTY_SH := $(PARENT_PROJECT_ROOT)/qwerty.sh

ifeq ($(GIT_DIR),)
export GIT_DIR := $(PARENT_PROJECT_ROOT)/.git
endif

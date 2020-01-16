all: lint

run: web-run

lint: sh-lint web-lint

install: web-install
deploy: web-deploy
deploy-restart: web-deploy-restart
http-proxied: web-http-proxied
https-proxied: web-https-proxied

sh-lint:
	@shellcheck -s sh -e $(SHELLCHECK_EXCLUDE) qwerty.sh

web-%:
	@$(MAKE) --no-print-directory -C web $*

SHELLCHECK_EXCLUDE := SC1007,SC2016,SC2086,SC2103,SC2119,SC2120,SC2156,SC2162

run: web-run

lint: web-lint
	@shellcheck -s sh -e SC1007,SC2119,SC2120,SC2086 qwerty.sh

install: web-install
deploy: web-deploy
deploy-restart: web-deploy-restart
http-proxied: web-http-proxied
https-proxied: web-https-proxied

web-%:
	@$(MAKE) --no-print-directory -C web $*

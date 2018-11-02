run: web-run

install: web-install
deploy: web-deploy
deploy-restart: web-deploy-restart
http-proxied: web-http-proxied
https-proxied: web-https-proxied

web-%:
	@$(MAKE) --no-print-directory -C web $*

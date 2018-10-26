run: web-run
deploy: web-deploy
install: web-install
http-proxied: web-http-proxied
https-proxied: web-https-proxied

web-%:
	@$(MAKE) -C web $*

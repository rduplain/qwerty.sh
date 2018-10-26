web-%:
	@$(MAKE) -C web $*

run: web-run
install: web-install
http-proxied: web-http-proxied
https-proxied: web-https-proxied

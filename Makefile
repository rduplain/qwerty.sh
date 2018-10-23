web-%:
	@$(MAKE) -C web $*

run: web-run
http-proxied: web-http-proxied
https-proxied: web-https-proxied

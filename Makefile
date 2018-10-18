%-web:
	@$(MAKE) -C web $*

run: run-web
http-proxied: http-proxied-web
https-proxied: https-proxied-web

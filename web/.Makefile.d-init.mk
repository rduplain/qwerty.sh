__FILE__ := $(abspath $(lastword $(MAKEFILE_LIST)))
DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

define qwerty-Makefile.d
cat $(abspath $(DIR)/../qwerty.sh) |\
	sh -s - \
	--sha256=0a7a636fa9c6d4838d2837884d66fd26f2cf910df9e62b6a24821f9235c7cf86 \
	https://github.com/rduplain/Makefile.d/tarball/04f0ab7 |\
		tar -xvzf - --strip-components=1
endef

.Makefile.d/%.mk: .Makefile.d/path.mk
	@touch $@

.Makefile.d/path.mk:
	@mkdir -p .Makefile.d
	cd .Makefile.d; $(qwerty-Makefile.d)
	@touch $@

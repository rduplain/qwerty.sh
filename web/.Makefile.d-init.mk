__FILE__ := $(abspath $(lastword $(MAKEFILE_LIST)))
DIR := $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

# On changes to .Makefile.d-init.mk, MAKEFILE_LIST may have lastword pointing
# to .Makefile.d/path.mk. To bootstrap using qwerty.sh, find it accordingly.
ifeq ($(notdir $(DIR)), "Makefile.d")
QWERTY_SH := $(abspath $(DIR)/../../qwerty.sh)
else
QWERTY_SH := $(abspath $(DIR)/../qwerty.sh)
endif

MAKEFILE_D_REPO := https://github.com/rduplain/Makefile.d.git
MAKEFILE_D_REF := 04f0ab7

.Makefile.d/%.mk: .Makefile.d/path.mk
	@touch $@

.Makefile.d/path.mk: $(__FILE__)
	cat $(QWERTY_SH) |\
		sh -s - -f -o .Makefile.d --ref $(MAKEFILE_D_REF) $(MAKEFILE_D_REPO)
	@touch $@

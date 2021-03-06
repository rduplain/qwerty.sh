MAKEFILE_D_INIT_MK := $(abspath $(lastword $(MAKEFILE_LIST)))
DIR := $(abspath $(dir $(MAKEFILE_D_INIT_MK)))

ifeq ($(QWERTY_SH),)
QWERTY_SH := $(abspath $(DIR)/../qwerty.sh)
endif

MAKEFILE_D_URL ?= https://github.com/rduplain/Makefile.d.git
MAKEFILE_D_REV ?= v1.4 # Use --ref instead of --tag below if untagged.

.Makefile.d/%.mk: .Makefile.d/path.mk
	@touch $@

.Makefile.d/path.mk: $(MAKEFILE_D_INIT_MK)
	$(QWERTY_SH) -f -o .Makefile.d --tag $(MAKEFILE_D_REV) $(MAKEFILE_D_URL)
	@touch $@

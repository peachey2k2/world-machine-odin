# This is only used for bootstrapping the nob binary
# which is the actual build system

all:
ifeq ($(wildcard ./nob),)
	$(MAKE) nobInit
endif

nobInit:
	cc -o nob nob.c
	$(info [✓] Bootstapped nob. Run ./nob for help.)
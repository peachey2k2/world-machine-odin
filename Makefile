all:
ifeq ($(wildcard ./nob),)
	$(MAKE) nobInit
endif
	./nob

nobInit:
	cc -o nob nob.c
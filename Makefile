
PACKAGE=luacov
VERSION=0.2
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
LUADIR=$(PREFIX)/share/lua/5.1/

install:
	mkdir -p $(BINDIR)
	cp src/bin/luacov $(BINDIR)
	mkdir -p $(LUADIR)
	cp src/luacov.lua $(LUADIR)
	mkdir -p $(LUADIR)/luacov
	cp src/luacov/stats.lua $(LUADIR)/luacov
	cp src/luacov/tick.lua $(LUADIR)/luacov

dist:
	rm -f dist.files
	rm -rf $(PACKAGE)-$(VERSION)
	rm -f $(PACKAGE)-$(VERSION).tar.gz
	find * | grep -v CVS > dist.files
	mkdir -p $(PACKAGE)-$(VERSION)
	cpio -p $(PACKAGE)-$(VERSION) < dist.files
	tar czvf $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -f dist.files
	rm -rf $(PACKAGE)-$(VERSION)

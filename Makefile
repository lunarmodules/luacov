
PACKAGE=luacov
VERSION=0.3
PREFIX=/usr/local
BINDIR=$(PREFIX)/bin
LUADIR=$(PREFIX)/share/lua/5.1/

install:
	mkdir -p $(BINDIR)
	cp src/bin/luacov $(BINDIR)
	mkdir -p $(LUADIR)
	cp src/luacov.lua $(LUADIR)
	mkdir -p $(LUADIR)/luacov
	cp src/luacov/*.lua $(LUADIR)/luacov

dist:
	rm -rf $(PACKAGE)-$(VERSION)
	rm -f $(PACKAGE)-$(VERSION).tar.gz
	mkdir -p $(PACKAGE)-$(VERSION)
	cp -a * $(PACKAGE)-$(VERSION)
	tar czvf $(PACKAGE)-$(VERSION).tar.gz $(PACKAGE)-$(VERSION)
	rm -rf $(PACKAGE)-$(VERSION)

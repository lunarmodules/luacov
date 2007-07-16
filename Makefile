
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


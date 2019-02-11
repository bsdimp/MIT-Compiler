DESTDIR = /usr/bin
DLDESTDIR = /usr/sun/bin
prom.dl: prom.c ACIA.c mul.c
	cc68 -vm -d prom.c

prom.sh: makefile
	echo dll $(DLDESTDIR)/prom.dl >prom.sh
	chmod a+x prom.sh

prom.press: prom.mss
	scribe prom

install: prom.dl prom.sh
	install -c prom.sh $(DESTDIR)/prom
	install -c prom.dl $(DLDESTDIR)/prom.dl

clean:
	rm -f prom.dl *.press *.otl *.aux

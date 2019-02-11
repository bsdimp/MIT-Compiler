#	The subdirectories contain files stolen from the Unix Version 7
#	libc stuff.  They are gradually being fixed to run on the 68000.
#	This makefile should describe all the files that have been modified.
#	Modified by WIN 3/82 to keep .b's in their subdirectories
#	Added cd math; make under libc.a Per Bothner 82/Jun
DESTDIR=/usr/sun/lib

SUBDIRS= stdio/*.b gen/*.b crt/*.b sunstuff/*.b emt/*.b math/*.b

libc: 
	cd stdio; make
	cd gen; make
	cd crt; make
	cd emt; make
	cd sunstuff; make
	cd math; make
	ar cr libc.a `lorder68 $(SUBDIRS) | tsort`

crtsun.b: crtsun.s
	cc68 -c crtsun.s

install: libc.a crtsun.b
	cp libc.a $(DESTDIR)/libc.a
	cp crtsun.b $(DESTDIR)/crtsun.b

clean:
	cd crt; make clean
	cd emt; make clean
	cd gen; make clean
	cd math; make clean
	cd sunstuff; make clean
	cd stdio; make clean
	cd test; make clean
	rm -f libc.a crtsun.b

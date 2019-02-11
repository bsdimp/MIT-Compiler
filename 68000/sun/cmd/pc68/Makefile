#makefile for pascal* stuff for the Sun
all:	ugen68 pc68 upas68 lopt68
	chmod g+w *
	size *68

clean:
	rm -f ugen68 pc68 upas68 lopt68 *.o *.b *BAK *CKP
	(cd run; make clean)
	(cd ugen; make clean)

pc68: pc68.c files.h
	cc pc68.c -o pc68

ugen68:
	make ugen/ugen68

upas:   upas.o
	pc -o upas uwri.o uini.o uscan.o upas.o

lopt68:   lopt68.p
	pc -w lopt68.p -o lopt68

install: upas ugen/ugen68 pc68 pc68.1
	cp upas ugen/ugen68 pc68 /usr/local/bin
	cp pc68.1 /usr/man/man1

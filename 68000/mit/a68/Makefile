FILES = mical.h inst.h scan.c error.c init.c ins.c io68.c\
	ps.c rel.c sdi.c sym.c /usr/include/b.out.h

OBJECTS = error.o init.o ins.o io68.o ps.o rel.o sdi.o sym.o scan.o
BOBJECTS = error.b init.b ins.b io68.b ps.b rel.b sdi.b sym.b scan.b

CFLAGS = -O

a68: $(OBJECTS)
	cc -o a68 $(OBJECTS)

a68.68: $(BOBJECTS)
	cc68 -o a68.68 $(BOBJECTS)

$(OBJECTS): mical.h
$(BOBJECTS): mical.h

init.o ins.o: mical.h inst.h

init.b ins.b: mical.h inst.h

rel.c:	mical.h /usr/include/b.out.h

sym.c:	mical.h /usr/include/b.out.h

.SUFFIXES:	.c .b

.c.b:
	cc68 -c $*.c


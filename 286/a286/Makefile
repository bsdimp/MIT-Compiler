FILES = mical.h inst.h scan.c error.c init.c ins.c \
	ps.c rel.c sdi.c sym.c

OBJECTS = error.o init.o ins.o ps.o rel.o sdi.o sym.o scan.o

CFLAGS = -O -DX286

a286: $(OBJECTS)
	cc -o a286 $(OBJECTS)

$(OBJECTS): mical.h

init.o ins.o: mical.h inst.h

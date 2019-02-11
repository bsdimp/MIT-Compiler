FILES = mical.h inst.h scan.c error.c init.c ins.c \
	ps.c rel.c sdi.c sym.c

OBJECTS = error.o init.o ins.o ps.o rel.o sdi.o sym.o scan.o

CFLAGS = -O -Dabort=MyAbort -Dexp=MyExp

try:	ncvt86 xee.ld
	ncvt86  xee.ld xee.com

ncvt86: ncvt86.o
	cc -o ncvt86 ncvt86.o

a86: $(OBJECTS)
	cc -o a86 $(OBJECTS)

$(OBJECTS): mical.h

init.o ins.o: mical.h inst.h

cvt86: cvt86.o
	cc -o cvt86 cvt86.o

ld86:	ld86.o
	cc -o ld86 ld86.o

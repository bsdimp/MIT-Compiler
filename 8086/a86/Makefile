FILES = mical.h inst.h scan.c error.c init.c ins.c \
	ps.c rel.c sdi.c sym.c

OBJECTS = error.o init.o ins.o ps.o rel.o sdi.o sym.o scan.o

KNR=-std=c89 -Wno-implicit-int -Wno-implicit-function-declaration -Wno-return-type
KNR_BAD=-Wno-bitwise-op-parentheses -Wno-dangling-else -I. -Wno-parentheses
CFLAGS = -O ${KNR} ${KNR_BAD}
ALL=a86 ncvt86

all:	${ALL}

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

clean:
	rm -f ${OBJECTS} ${ALL}

# Description file for 68000 assembler

CFLAGS =	-c -O -I../../../include -DBOOTSTRAP -DStanford

OFILES =	as.o cond.o error.o eval.o init.o ins.o mac.o oper.o print.o\
		ps.o ps1.o ps2.o ps3.o random.o rel.o sdi.o spawn.o sym.o
 
as68: $(OFILES)
	cc  -o as68 $(OFILES)

$(OFILES): mical.h

mac.o: mical.h mac.h

init.o ins.c: mical.h inst.h

install:
	cp as68 /usr/local/bin/as68

clean:
	rm -f *CKP *BAK *.o as68

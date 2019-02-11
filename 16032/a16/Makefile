#CFLAGS = -O -I../include
CFLAGS = -g -I../include


FILES = ../include/a.out.h ../include/operands.h mical.h optable \
	error.c init.c ins.c ps.c rel.c scan.c sdi.c sym.c

OBJECTS = error.o init.o ins.o ps.o rel.o scan.o sdi.o sym.o


a16: $(OBJECTS)
	cc -o a16 $(OBJECTS)

$(OBJECTS): mical.h ../include/operands.h

optable: opcodes maketab
	maketab opcodes optable

maketab: maketab.c
	cc -o maketab maketab.c

error.o:

init.o:   optable

ins.o:    ../include/a.out.h

ps.o:     ../include/a.out.h

rel.o:    ../include/a.out.h

scan.o:   

sdi.o:    

sym.o:    ../include/a.out.h

list:
	prd opcodes *.h *.c | dover

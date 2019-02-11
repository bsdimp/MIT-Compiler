XCFLAGS=  -O  -Dmc68000

FILES = cgram.c xdefs.c scan.c pftn.c trees.c optim.c code.c local.c \
	reader.c local2.c order.c match.c allo.c comm1.c table.c

OBJ1 =	trees.o optim.o pftn.o code.o local.o scan.o xdefs.o cgram.o comm1.o 
OBJ2 =  table.o reader.o local2.o order.o match.o allo.o

HEADS =	common macdefs mac2defs mfile1 mfile2 manifest 

ccom:		$(OBJ1) $(OBJ2)
		$(CC) $(CFLAGS) -n -x -o $@ $(OBJ1) $(OBJ2)

install:	ccom
		install -s ccom /lib
		touch ccom install

mfile1:	macdefs manifest
	touch mfile1

mfile2:	macdefs mac2defs manifest
	touch mfile2

manifest: /usr/include/stdio.h

comm1.o: mfile1 common 

code.o: mfile1 /usr/include/signal.h /usr/include/stdio.h

cgram.c: cgram.y
	yacc cgram.y
	mv y.tab.c cgram.c

$(OBJ1): mfile1
	$(CC) -c $(XCFLAGS) $*.c

$(OBJ2): mfile2
	$(CC) -c $(XCFLAGS) $*.c

prall:	$(FILES) $(HEADS)
	npr $(HEADS) 
	npr $(FILES)
	touch prall


XCFLAGS=-O
c68: cgram.o xdefs.o scan.o pftn.o trees.o optim.o code.o local.o reader.o \
	local2.o order.o match.o allo.o comm1.o table.o
	cc $(XCFLAGS) cgram.o xdefs.o scan.o pftn.o trees.o optim.o code.o \
	local.o  reader.o local2.o order.o match.o allo.o comm1.o table.o
	mv a.out c68

c68.68: cgram.b xdefs.b scan.b pftn.b trees.b optim.b code.b local.b \
	reader.b local2.b order.b match.b allo.b comm1.b table.b
	ucc68 $(XCFLAGS) cgram.b xdefs.b scan.b pftn.b trees.b optim.b code.b \
	local.b  reader.b local2.b order.b match.b allo.b comm1.b table.b
	mv b.out c68.68

trees.o: manifest macdefs mfile1 trees.c
	cc -c $(XCFLAGS) trees.c

optim.o: manifest macdefs mfile1 optim.c
	cc -c $(XCFLAGS) optim.c

pftn.o: manifest macdefs mfile1 pftn.c
	cc -c $(XCFLAGS) pftn.c

code.o: manifest macdefs mfile1
	cc -c $(XCFLAGS) code.c

local.o: manifest macdefs mfile1
	cc -c $(XCFLAGS) local.c

scan.o: manifest macdefs mfile1 scan.c
	cc -c $(XCFLAGS) scan.c

xdefs.o: manifest mfile1 macdefs xdefs.c
	cc -c $(XCFLAGS) xdefs.c

cgram.o: manifest mfile1 macdefs cgram.c
	cc -c $(XCFLAGS) cgram.c

cgram.c: cgram.y
	yacc cgram.y
	mv y.tab.c cgram.c

comm1.o: manifest mfile1 common macdefs comm1.c
	cc -c $(XCFLAGS) comm1.c

table.o: manifest mfile2 mac2defs macdefs table.c
	cc -c $(XCFLAGS) table.c

reader.o: manifest mfile2 mac2defs macdefs reader.c
	cc -c $(XCFLAGS) reader.c

local2.o: manifest mfile2 mac2defs macdefs
	cc -c $(XCFLAGS) local2.c

order.o: manifest mfile2 mac2defs macdefs
	cc -c $(XCFLAGS) order.c

match.o: manifest mfile2 mac2defs macdefs match.c
	cc -c $(XCFLAGS) match.c

allo.o: manifest mfile2 mac2defs macdefs allo.c
	cc -c $(XCFLAGS) allo.c

.SUFFIXES:	.c .b

.c.b:
	ucc68 -c $*.c


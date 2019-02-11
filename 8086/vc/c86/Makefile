CFLAGS=-O
COMP=/u1/8086/bin/cc86

.SUFFIXES:
.SUFFIXES:	.b .o .c

.c.b:
	$(COMP) -c -DBUG4 $<


OBJ0b=	trees1.b trees2.b optim.b pftn1.b pftn2.b code.b local.b scan.b \
	xdefs.b cgram.b
OBJ1b=	reader.b order.b match.b allo.b comm1.b local2.b table.b

c0:		$(OBJ0b) $(OBJ1b)
	$(COMP) -s -i -o c0 $(OBJ0b) $(OBJ1b)

table.b: table.c
	$(COMP) -c table.c

OBJ0=	trees1.o trees2.o optim.o pftn1.o pftn2.o code.o local.o scan.o \
	xdefs.o cgram.o
OBJ1=	reader.o order.o match.o allo.o comm1.o local2.o table.o

c86:	$(OBJ0) $(OBJ1)
	cc -o c86 $(OBJ0) $(OBJ1)

table.o: table.c
	cc -c table.c

comm1.o	comm1.b: manifest mfile1 common macdefs
$(OBJ0) $(OBJ0b): manifest macdefs mfile1
$(OBJ1) $(OBJ1b): manifest mfile2 mac2defs macdefs

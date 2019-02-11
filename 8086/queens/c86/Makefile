CFLAGS=-O

OBJ0 = trees.o optim.o pftn.o code.o local.o scan.o xdefs.o cgram.o
OBJ1 = table.o reader.o local2.o order.o match.o allo.o

c86:	$(OBJ0) $(OBJ1) comm1.o
	cc -o c86 $(OBJ0) $(OBJ1) comm1.o

local2.o: local2.c
	cc -c -O -DX8087 local2.c

table.o: table.c
	cc -c -O -DX8087 table.c

comm1.o: manifest mfile1 common macdefs
$(OBJ0): manifest macdefs mfile1
$(OBJ1): manifest mfile2 mac2defs macdefs


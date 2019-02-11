CFLAGS=-O

OBJ0 = trees.o optim.o pftn.o code.o local.o scan.o xdefs.o cgram.o
OBJ1 = table.o reader.o local2.o order.o match.o allo.o

ccom:	$(OBJ0) $(OBJ1) comm1.o
	cc -o ccom $(OBJ0) $(OBJ1) comm1.o

comm1.o: manifest mfile1 common macdefs
$(OBJ0): manifest macdefs mfile1
$(OBJ1): manifest mfile2 mac2defs macdefs

list:
	prd manifest mfile1 mfile2 macdefs mac2defs common *.c | dover

save:
	ar rc SAVE.a manifest mfile1 mfile2 macdefs mac2defs common *.c

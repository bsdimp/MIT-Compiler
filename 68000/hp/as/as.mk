PATHX = /usr

FILES = mical.h inst.h scan.c error.c init.c ins.c\
	ps.c rel.c sdi.c sym.c $(PATH)/include/a.out.h

OBJECTS = error.o init.o ins.o ps.o rel.o sdi.o sym.o scan.o

CFLAGS = -O -Dmc68000

as:	$(OBJECTS)
	$(CC) -n -x -o as $(OBJECTS)
	@echo "AS MAKEFILE COMPLETE. NO INSTALLATION."

install:	as
		install -s as /bin
		touch as install
		@echo "AS MAKEFILE COMPLETE WITH INSTALLATION."

$(OBJECTS): 		mical.h

error.o:		error.c

init.o ins.o:		inst.h

init.o:			init.c

ins.o:			ins.c

ps.o:			ps.c

rel.o:			rel.c

sdi.o:			sdi.c

sym.o:			sym.c

scan.o:			scan.c

mical.h:		$(PATHX)/include/stdio.h

rel.o sym.o init.o:	$(PATHX)/include/a.out.h



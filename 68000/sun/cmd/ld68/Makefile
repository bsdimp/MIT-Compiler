#Description file for .b file linker and utilities
#Say 'make' to bring all command files in ld up to date.  Say 'make install'
#to copy any new command files to BIN.

BIN = /usr/local/bin
INCLUDE = /usr/sun/include

all:		ld68 nm68 rl68 size68 pr68 rev68 dl68

ld68:		 ld.c
		cc -o ld68 -O -DStanford -DBOOTSTRAP -I$(INCLUDE) ld.c

nm68:		 nm68.c
		cc -o nm68 -O -I$(INCLUDE) nm68.c 

rl68:		 rl68.c
		cc -o rl68 -O -I$(INCLUDE) rl68.c

size68:		 size68.c
		cc -o size68 -O -I$(INCLUDE) size68.c

pr68:		 pr68.c
		cc -o pr68 -O -I$(INCLUDE) pr68.c

rev68:		 rev68.c
		cc -o rev68 -O -I$(INCLUDE) rev68.c

dl68:		 dl68.c
		cc -o dl68 -O -I$(INCLUDE) dl68.c

install:	$(BIN)/ld68 $(BIN)/nm68 $(BIN)/rl68 $(BIN)/size68 $(BIN)/pr68 $(BIN)/rev68 $(BIN)/dl68

$(BIN)/ld68:	ld68
		cp ld68 $(BIN)

$(BIN)/nm68:	nm68
		cp nm68 $(BIN)

$(BIN)/rl68:	rl68
		cp rl68 $(BIN)

$(BIN)/size68:	size68
		cp size68 $(BIN)

$(BIN)/pr68:	pr68
		cp pr68 $(BIN)

$(BIN)/rev68:	rev68
		cp rev68 $(BIN)

$(BIN)/dl68:	dl68
		cp dl68 $(BIN)

clean:
	rm -f *.o dl68 ld68 nm68 pr68 rev68 rl68 size68

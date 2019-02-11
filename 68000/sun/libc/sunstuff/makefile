# Makefile for libc/sunstuff (MC68000)
# Modified by Bill Nowicki April 1982
#	- Added ddtinit
#	- Added a clean option
.SUFFIXES: .b .c .s

OBJS = chrtab.b exit.b getchar.b printf.b putchar.b \
	termbas.b ttyio.b getenv.b signal.b ddtinit.b

all: $(OBJS)

# how to make a .b file from a .c file
.c.b:
	cc68 -O -c $*.c

# how to make a .b file from a .s file
.s.b:
	cc68 -c $*.s

clean:
	rm -f *.b *CKP *BAK

# Makefile for libc/emt (MC68000)
.SUFFIXES: .b .c .s

OBJS = emtcall.b emtgetchar.b emtputchar.b getcontext.b getmemsize.b \
	getsegmap.b setcontext.b setecho.b setsegmap.b ticks.b version.b \
	getconfig.b fbmode.b


all: $(OBJS)

# how to make a .b file from a .c file
.c.b:
	cc68 -O -c $*.c

# how to make a .b file from a .s file
.s.b:
	cc68 -c $*.s

clean:
	rm -f *.b *CKP *BAK

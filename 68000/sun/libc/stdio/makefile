# Makefile for libc/stdio
# Modified by Bill Nowicki April 1982

.SUFFIXES: .b .c .s

OBJS = clrerr.b data.b doprnt.b doscan.b fgetc.b fgets.b filbuf.b flsbuf.b \
	fprintf.b fputc.b fputs.b gcvt.b gets.b getw.b puts.b putw.b scanf.b \
	setbuf.b sprintf.b strout.b ungetc.b

all: $(OBJS)

# how to make a .b file from a .c file
.c.b:
	cc68 -O -c $*.c

# how to make a .b file from a .s file
.s.b:
	cc68 -c $*.s

clean: 
	rm -f *.b *CKP *BAK

#(*) UNIX is a trademark of Bell Laboratories

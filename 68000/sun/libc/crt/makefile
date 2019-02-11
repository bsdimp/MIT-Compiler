# Makefile for libc/crt (MC68000)
.SUFFIXES: .b .c .s

OBJS = abort.b aldiv.b almul.b alrem.b auldiv.b aulmul.b aulrem.b \
	float.b ldiv.b lmul.b lrem.b makefile uldiv.b ulmul.b ulrem.b

all: $(OBJS)

# how to make a .b file from a .c file
.c.b:
	cc68 -O -c $*.c

# how to make a .b file from a .s file
.s.b:
	cc68 -c $*.s

clean:
	rm -f *.b *CKP *BAK

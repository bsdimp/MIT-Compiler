# Makefile for libc/gen (MC68000)
.SUFFIXES: .b .c .s

OBJS = abs.b atoi.b atof.b atol.b blt.b clear.b crypt.b ctype_.b \
	ecvt.b index.b qsort.b rand.b rindex.b setjmp.b \
	strcat.b strcatn.b strcmp.b strcmpn.b strcpy.b strcpyn.b \
	strlen.b strncat.b strncmp.b strncpy.b swab.b 

# these files are UNIX(*)-dependent and we aren't running UNIX yet
UNIXYOBJS = allocs.b calloc.b ctime.b cuexit.b errlst.b execvp.b fakcu.b \
	getenv.b getlogin.b isatty.b l3.b malloc.b mktemp.b mon.b nlist.b\
	perror.b sleep.b stty.b tell.b timezone.b ttyname.b ttyslot.b


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

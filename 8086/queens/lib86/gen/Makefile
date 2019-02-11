.SUFFIXES: .d
.c.d: ; bb86 -c $<

OBJECTS =	abs.d atoi.d blt.d atof.d atol.d  calloc.d crypt.d\
		ctime.d ctype_.d cuexit.d ecvt.d errlst.d execvp.d clear.d\
		getenv.d getlogin.d index.d isatty.d l3.d\
		malloc.d mfill.d frexp.d\
		mktemp.d mon.d perror.d qsort.d rand.d\
		rindex.d sleep.d strcat.d strcatn.d strcmp.d strcmpn.d\
		strcpy.d strcpyn.d strlen.d strncat.d strncmp.d strncpy.d\
		stty.d swab.d tell.d timezone.d ttyname.d ttyslot.d\
		setjmp.d

all:		$(OBJECTS)

blt.d:		blt.b86
		a86 blt

clear.d:	clear.b86
		a86 clear

mfill.d:	mfill.b86
		a86 mfill

setjmp.d:	setjmp.b86
		a86 setjmp

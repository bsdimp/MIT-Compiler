.SUFFIXES: .d
.c.d: ; bb86 -c $<

OBJECTS =	fprintf.d sprintf.d printf.d scanf.d clrerr.d doscan.d\
		doprnt.d fdopen.d fgetc.d fopen.d fgets.d fputc.d\
		fputs.d freopen.d fseek.d ftell.d gcvt.d gets.d getw.d \
		putchar.d puts.d putw.d	rdwr.d rew.d strout.d\
		system.d ungetc.d setbuf.d flsbuf.d filbuf.d data.d

all:		$(OBJECTS)

$(OBJECTS):	../include/stdio.h

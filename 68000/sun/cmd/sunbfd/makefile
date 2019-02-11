# makefile for sunbfd (boot file directory) program
# JCM 19 Feb 81, 9 June 1981

CFLAGS= -c -g -DVAX
COPTS= -O -DVAX

OBJS= sunbfd.o sunbddecode.o msunbootdir.o
NOBJS= newbfd.o sunbddecode.o msunbootdnew.o

newbfd: $(NOBJS)
	cc -o newbfd $(NOBJS) -lpup

sunbfd: $(OBJS)
	cc -o sunbfd $(OBJS) -lpup

sunbfd.o: sunbfd.c sunbfd.h
	cc $(COPTS) $(CFLAGS) sunbfd.c

sunbddecode.o: sunbddecode.c sunbfd.h
	cc $(COPTS) $(CFLAGS) sunbddecode.c

msunbootdir.o: msunbootdir.c
	cc $(COPTS) $(CFLAGS) msunbootdir.c

msunbootdnew.o: msunbootdnew.c
	cc $(COPTS) $(CFLAGS) msunbootdnew.c

clean:
	rm -f $(OBJS) *.b *.r *.o *CKP *BAK newbfd newbfd68 sunbfd sunbfd68

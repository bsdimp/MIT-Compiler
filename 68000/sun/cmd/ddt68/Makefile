# Makefile for ddt68
# Documented by Bill Nowicki January 1982

S = /usr/sun
M = bpt.b ddt.b dasmsub.b
OBJVAX = ddt.o dasmsub.o
CC = cc -g
.SUFFIXES: .b .s .a68 .dl

.c.b .s.b .a68.b:
	cc68 -c $<

#all:	fddt68 ddt68 ddt68.dl DDT68.dl

#install:
#	cp ddt68 $S/bootfile

$S/lib/libddt.a:	$M
	ar ruv $S/lib/libddt.a $M


ddt68:	$M
	cc68 $M -r -o ddt68

ddt68.dl: $M
	cc68 -s -d -T 1a000 $M -o ddt68.dl

fddt68:	$(OBJVAX)
	$(CC) $(OBJVAX) -o fddt68

DDT68.dl: bpt.b ddt.b dmdasmsub.b
	cc68 -s -vm -d -T 5000 bpt.b ddt.b dmdasmsub.b -o DDT68.dl

ddt.b:	ddt.h ddt.c

ddt.o:	ddt.h ddt.c

dasmsub.b:	ddt.h dasmsub.c ea68.c ops68.c

dmdasmsub.b:	ddt.h dasmsub.c ea68.c ops68.c
	cc68 -DDM -c dasmsub.c -o dmdasmsub.b

dasmsub.o: ddt.h dasmsub.c vea68.c vops68.c

ea68.c:	ea68 inscom
	inscom < ea68 > ea68.c

ops68.c: ops68 inscom
	inscom < ops68 > ops68.c

vea68.c: ea68 vinscom
	vinscom < ea68 > vea68.c

vops68.c: ops68 vinscom
	vinscom < ops68 > vops68.c

inscom:	inscom.c
	cc inscom.c -o inscom

vinscom: vinscom.c
	cc vinscom.c -o vinscom

clean:
	rm -f *.b *.o *.out *.dl ddt68 inscom fddt68 vinscom

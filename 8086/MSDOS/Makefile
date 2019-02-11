CC = /src/Machines/8086/MSDOS/cc86

test.com:	test.b libc.a crt0.b
		$(CC) -o test test.b
		sendall test.com

libc.a:		msd2dot0.b sys2.b
		ar r libc.a msd2dot0.b sys2.b
		ranlib libc.a

test.b:		test.c
		ncc86 -c test.c

msdos:		msd2dot0.b sys2.b crt0.b

crt0.b:		crt0.a86
		a86 crt0

msd2dot0.b:	msd2dot0.a86
		a86 msd2dot0

sys2.b:		sys2.c
		ncc86 -c sys2.c

msd2dot0.a86:	MSD2DOT0.A86
		unixify MSD2DOT0.A86

sys2.c:		SYS2.C
		unixify SYS2.C

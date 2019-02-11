.SUFFIXES: .b .c .s

t1.r: t1.b float.b mine.b
	cc68 -r -o t1.r t1.b mine.b
t1.x: t1.b mine.b
	cc68 -X -o t1.x t1.b mine.b

float.b: float.a68
	/usr/sun/newa68/a68 float.a68

mine.b: mine.a68
	/usr/sun/newa68/a68 mine

# how to make a .b file from a .c file
.c.b:
	cc68 -O -c $*.c

# how to make a .b file from a .s file
.s.b:
	cc68 -c $*.s

clean:
	rm -f *.b *CKP *BAK

#(*) UNIX is a trademark of Bell Laboratories

.SUFFIXES: .b .c .s

send: send.b
	cc68 -r -o send send.b -lpup

install-send: send
	cp send /usr/sun/bootfile/send
	chmod a-x /usr/sun/bootfile/send
	chmod g+x /usr/sun/bootfile/send

clean:
	rm -f *.o *.b *.s send

# how to make a .b file from a .c file
.c.b:
	cc68 -O -c $*.c

# how to make a .b file from a .s file
.s.b:
	cc68 -c $*.s


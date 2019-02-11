DESTDIR=

all: libc.a crtx

libc.a:
	cd crt; make
	cd sys; make
	cd gen; make
	cd stdio; make
	ls crt/*.b gen/*.b sys/*.b stdio/*.b | sort -t/ +1 > t1
	ar cr libc.a `lorder \`cat t1\` | tsort`;
	ranlib libc.a
	rm -f t1

crtx:
	cd csu; make

dover:	/tmp/lib86.press
	dover /tmp/lib86.press

press:	/tmp/lib86.press

/tmp/lib86.press:
	apr Makefile */Makefile */*.[hc] | prd >/tmp/lib86.press


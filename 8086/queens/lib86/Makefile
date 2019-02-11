DESTDIR=

all: libc.a crtx

libc.a:
	cd crt; make
	cd sys; make
	cd gen; make
	cd stdio; make
	ar rv libc.a crt/*.d gen/*.d sys/*.d stdio/*.d
	ranlib libc.a

crtx:
	cd csu; make

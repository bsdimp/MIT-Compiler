# sun command makefile (or beginings thereof)
# Bill Nowicki December 1981
# merged a bunch of uncommented files
# March 15, 1982 (win) changed /usr/bin to /usr/local/bin

DESTDIR= /usr/local/bin

sun-commands: dll dlx cc68 compiler assembler loader prom

archive:
	tar cvf ac68.tar cc68.c as ccom ld68

install: $(DESTDIR)/dll $(DESTDIR)/dlx $(DESTDIR)/cc68 \
 install-compiler install-assembler install-loader install-prom

dll: dll.c
	cc -o dll dll.c
$(DESTDIR)/dll: dll
	install -s dll $(DESTDIR)/dll

dlx: dlx.c
	cc -o dlx dlx.c
$(DESTDIR)/dlx: dlx
	install -s dlx $(DESTDIR)/dlx

cc68: cc68.c
	cc -o cc68 cc68.c
$(DESTDIR)/cc68: cc68
	install -s cc68 $(DESTDIR)/cc68

install-compiler:
	(cd ccom; make install)

install-loader:
	(cd ld68; make install)

install-assembler:
	(cd as; make install)

install-pascal:
	(cd pc68; make install)

install-prom:
	(cd prom; make install)

compiler:
	(cd ccom; make)

loader:
	(cd ld68; make)

assembler:
	(cd as; make)

pascal:
	(cd pc68; make)

prom:
	(cd prom; make)

clean:
	rm -f dll cc68 dlx *.b *.o *BAK *CKP
	(cd as; make clean)
	(cd c2; make clean)
	(cd ccom; make clean)
	(cd ddt68; make clean)
	(cd ld68; make clean)
	(cd pc68; make clean)
	(cd prom; make clean)
	(cd send; make clean)
	(cd sunbfd; make clean)

#careful about order of components!

PIO68 =	\
        rdr.b wrr.b initstd.b date.b      filepos.b   filestat.b initfile.b  \
	rdb.b       rdlirange.b rdli.b      rdpage.b    eopage.b    \
	rds.b       rdset.b     rdcrange.b  rdirange.b  rdi.b       \
	parseint.b  rdscalar.b  rdident.b   rdups.b     rdc.b       \
	res.b       rew.b       getfname.b  bufval.b    openttin.b  \
	rln.b       eln.b       eof.b       get.b       getb.b      \
	perror.b    stty.b      time.b      misc.b      wrb.b       \
	wrc.b       wrli.b      wrpage.b    wrset.b     caseerr.b   \
	close.b     opnttout.b  open.b      wln.b       wri.b       \
	wrs.b       wrscalar.b  wrups.b     wr1c.b      halt.b      \
	put.b       utilities.b xit.b       break.b     wrr.b       \
	setmasks.b  display.b	hptr.b	round.b mathstubs.b


PIOVAX = date.o      filepos.o   filestat.o initfile.o  \
	rdb.o       rdlirange.o rdli.o      rdpage.o    eopage.o    \
	rds.o       rdset.o     rdcrange.o  rdirange.o  rdi.o       \
	parseint.o  rdscalar.o  rdident.o   rdups.o     rdc.o       \
	res.o       rew.o       getfname.o  bufval.o    openttin.o  \
	rln.o       eln.o       eof.o       get.o       getb.o      \
	perror.o    stty.o      time.o      misc.o      wrb.o       \
	wrc.o       wrli.o      wrpage.o    wrset.o     caseerr.o   \
	close.o     opnttout.o  open.o      wln.o       wri.o       \
	wrs.o       wrscalar.o  wrups.o     wr1c.o      halt.o      \
	put.o       utilities.o xit.o       break.o     


.SUFFIXES: .body .o .b .p .c .s .lib68 .libvax

.c.b:
	cc68 -DDEBUG -DLEAF -DMC68000 -c $?
.c.s:
	cc68 -DDEBUG -DLEAF -DMC68000 -S $?

.c.o:
	cc -c $?
.p.o:
	/mnt/star/pcvax/pcvax -L -c $?
.s.b:
	cc68 -c $?

.body.b:
	cat pio68.header $*.body >$*.p
	pc68 -c $*.p
	rm $*.p

.body.p:
	cat pio68.header $*.body >$*.p

.p.b:
	pc68 -c $*.p

.b.lib68:
	ar	r libpc68.a $*.b

.o.libvax:
	ar	r libpcvax.a $*.o

libpc68.a:     $(PIO68) 
	-rm	libpc68.a /usr/sun/dm/lib/libpc68.a /usr/sun/lib/libpc68.a 
	ar	cr libpc68.a $(PIO68) 
	ln	libpc68.a /usr/sun/dm/lib/libpc68.a 
	ln	libpc68.a /usr/sun/lib/libpc68.a
	chmod	g+w /usr/sun/dm/lib/libpc68.a /usr/sun/lib/libpc68.a

libpcvax.a:  $(PIOVAX) 
	-rm	/usr/lib/libpcvax.a libpcvax.a
	ar	cr libpcvax.a $(PIOVAX) 
	ranlib	libpcvax.a
	ln	libpcvax.a /usr/lib/libpcvax.a
	chmod	g+w /usr/lib/libpcvax.a *

dummy68:	$(PIO68)
	echo	would remake libraries here

dummyvax:	$(PIOVAX)
	echo	would remake libraries here

newvax:		/mnt/star/pcvax/ugenvax
	/mnt/star/pcvax/pcvax -L -c *.p

clean: clearvax clear68
	rm -f *.l

clearvax:    
	rm -f *.o *.u *.s core symtbl

clear68:    
	rm -f *.b *.u *.a68 *.ls core symtbl ugen68.log upas68.log *.uco

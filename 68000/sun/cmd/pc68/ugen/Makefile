OBJECTS = uscan.o uread.o uini.o ugst.o ugtm.o ugat.o ugcd.o ugrg.o ugsp.o ugtp.o

ugen68: $(OBJECTS)
	pc -o ugen68 $(OBJECTS)
	# *** remember to cp ugen68 to /usr/local/bin, if appropriate

SUFFIXES: .p .o

.p.o:
	pc -c -g -w $*.p

clean:
	rm -f *.o *.old *BAK *CKP *.l

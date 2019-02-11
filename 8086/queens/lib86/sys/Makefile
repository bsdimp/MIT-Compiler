.SUFFIXES: .d
.c.d: ; bb86 -c $<

OBJECTS=	dos.d io.d ttyio.d userio.d

all:		$(OBJECTS)

dos.d:	dos.b86
	a86 dos

io.d: io.b86
	a86 io

.SUFFIXES: .b
.c.b: ; cc86 -c $<

OBJECTS=	dos.b handler.b io.b syscalls.b ttyio.b userio.b

all:		$(OBJECTS)

dos.b:	dos.a86
	a86 dos

handler.b: handler.a86
	a86 handler

io.b: io.a86
	a86 io

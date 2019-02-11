#include <stdio.h>


get68(file, p, c)
register FILE	*file;
register char	*p;
register c;
{
	if(c == 2) {
		*(short *)p = getc(file);
		*(short *)p = *(short *)p << 8 | getc(file);
	}
	else {
		*(long *)p = getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
		*(long *)p = *(long *)p << 8 | getc(file);
	}
}


put68(file, p, c)
register FILE	*file;
register char	*p;
{
	if(c == 2) {
		putc(*(short *)p >> 8, file);
		putc(*(short *)p, file);
	}
	else {
		putc(*(long *)p >> 24, file);
		putc(*(long *)p >> 16, file);
		putc(*(long *)p >> 8, file);
		putc(*(long *)p, file);
	}
}

#include "txtfdb.h"
#include "macros.m"
#ifdef MC68000
_xit( haltcode )
#else
#include <stdio.h>
_xit( haltcode )
#endif
	int haltcode;
{	char *cp;

	for ( cp = "\n***HALTED***\n"; *cp; )
		putchar(*cp++);
#ifdef MC68000
	asm("	trap   #14");
#else
        fflush(stdout);
        fflush(stderr);
	abort(haltcode);
#endif

}

#include "txtfdb.h"
#include "macros.m"
#ifdef MC68000
#ifdef LEAF
#include <stdio.h>
#endif
_put( FDB )
#else
#include <stdio.h>
_put( FDB )
#endif
	struct txtfdb *FDB;
{ register n; register char *p;

	if ( (FDB->status) != OPENOUTPUT )
	{
		invalid(FDB, "PUT -- file not open for output");
		EXIT(-1);
	}

	COMMENT("|***actually write to file");
	n = (FDB->pbuffersize + 7) >> 3; p = &(FDB->pbuffer);
#ifdef LEAF
	if (FDB->device == LEAFDEV)
	    while (n--) putc(*p++, File(FDB));
	else
#endif
	    while (n--) emt_putchar(*p++);
}

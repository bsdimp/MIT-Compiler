#include "txtfdb.h"
#include "macros.m"
#ifdef LEAF
#include <stdio.h>
#endif
#ifdef MC68000
_getb( FDB )
#else
#include <stdio.h>
_getb( FDB )
#endif
	struct txtfdb *FDB;
{
	register int	i;
	register char	*cp;

	if ( (FDB->status) != OPENINPUT )
	{	invalid(FDB, "GETB -- file not open for input");
		(FDB->status) = OPENINPUT;
	}

	if ( ISTRUE(FDB->eofflag) )
	{	invalid(FDB, "GETB -- attempt to read past eof");
		EXIT(-1);
	}

	COMMENT("|***actually read in buffer from file");
#ifndef LEAF
	if ( ISTRUE(FDB->ttymode) )
#else
	if (0)
#endif
	{	COMMENT("|***line at a time ");
		if ( (FDB->charpos) > (FDB->charlast) )
		{	i = 0;
			for ( ; ; )
			{	cp = &(FDB->charbuf[i++]);
				inputchar(*cp);
				if ( *cp== '\n' )
					break;
				else if ( *cp== ERASE )
					i -= 2;
				else if ( *cp== KILL )
					i = 0;
				else if ( *cp== ENDFILE )
					break;
			}
			(FDB->charpos)  = 0;
			(FDB->charlast) = i-1;
		}
		COMMENT("|***actually return character");
		(FDB->pbuffer) =  (FDB->charbuf[(FDB->charpos)]);
		(FDB->charpos) += 1;
	}
#ifdef LEAF
	else if (FDB->filetype == BINARY) {
	    if (FDB->eofflag = feof(File(FDB))) {}
	    else {
	        register n = ((FDB->pbuffersize + 7) >> 3) - 1;
		register char *p = &(FDB->pbuffer);
	        while (n--) *p++ = getc(File(FDB));
		if (FDB->eofflag = feof(File(FDB)))
		    invalid(FDB, "GETB -- premature end of file for binary file");
		else *p++ = getc(File(FDB));
	    }
	} else if (FDB->device == LEAFDEV) {
	    FDB->eofflag = feof(File(FDB));
	    if (FDB->eofflag) FDB->pbuffer = ENDFILE;
	    else
	        FDB->pbuffer = getc(File(FDB));
	}
#endif
	else
	{	inputchar((FDB->pbuffer));
	}
	COMMENT("|***test for end of file");
	if ( (FDB->pbuffer) == ENDFILE && FDB->device!=LEAFDEV )
	{	(FDB->eofflag) = TRUE;
	}
}

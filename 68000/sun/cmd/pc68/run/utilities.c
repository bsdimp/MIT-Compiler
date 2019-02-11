/*	utility routines used by primitive.c */
#	include	"txtfdb.h"
#ifndef MC68000
#include <stdio.h>
#endif

char *strupper( str, length )
	register char 	*str;
	register int  	 length;
{	register char 	*s;
	
	s = str;
	for ( ; length ; --length, s++ )
		if ( *s > 'Z' )
			*s -= ('a'-'A');
	return(str);
}

int	namecomp( cp1, cl1, cp2, cl2 )
	register char *cp1, *cp2;
	register int  cl1,  cl2;
{
	/*  comparison is only valid for equal length strings */
		if (cl1-cl2)
			return(cl1-cl2);
	
	/*	compare only for the length of the two strings */
	    return( strncmp(
#ifdef LEAF
		cp1,
#else
		strupper(cp1, cl1),
#endif
		cp2, cl1 ) );
}

invalid( FDB, msg )
	register struct txtfdb *FDB;
	register char		  *msg;
{
	register int i;
	register char *cp;

	for ( cp = "\n***ERROR IN "; *cp; )
		putchar(*cp++);

	for ( cp = msg; *cp; )
		putchar(*cp++);

	for ( cp = " -- user file is "; *cp; )
		putchar(*cp++);

	i = IDENTLENGTH;
	while (FDB->prompt[i] == ' ' && i > 0) i--;
	for (cp = FDB->prompt; i; i--) putchar(*cp++);

	putchar('\n');
#ifdef DEBUG
	printf("status:	%x\tdevice:	%x\teofflag:	%x\n",
		(FDB->status), (FDB->device), (FDB->eofflag));
	printf("bufferinvalid:	%x\tfiletype:	%x\tttymode:	%x\n",
		(FDB->bufferinvalid), (FDB->filetype), (FDB->ttymode));
	printf("eolnflag:	%x\teopageflag:	%x\npbuffer:	%x\t",
		(FDB->eolnflag), (FDB->eopageflag), (FDB->pbuffer));
	printf("channel:	%x\n", FDB->channel);
#endif
}

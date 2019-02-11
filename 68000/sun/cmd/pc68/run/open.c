#ifdef LEAF
#define maxFileName 200
#include <stdio.h>
#endif
#include "txtfdb.h"
#include "macros.m"
_open( FDB, name, namelength, openinput, protection )
	char *name;
	struct txtfdb *FDB;
	boolean	   openinput;
	int	   protection;
{
  char str[maxFileName];
    COMMENT("|***make sure that file isn't already open ");
	if ( (FDB->status) != NOTOPEN )
	{	invalid(FDB, "OPEN -- file already open");
		(FDB->status) = NOTOPEN;
	}
    COMMENT("|***set filestatus ");
	if ( openinput )
	{	(FDB->status) = OPENINPUT;
#ifdef LEAF
		File(FDB) = stdin;
#endif
	}
	else
	{	(FDB->status) = OPENOUTPUT;
#ifdef LEAF
		File(FDB) = stdout;
#endif
	}

    FDB->device = TTYDEV;
    (FDB->charpos)  = 0;
    (FDB->charlast) = -1;


    COMMENT("|***check file name for appropriateness ");
    if ( namecomp( name, namelength, "TTY:", 4 )
      && namecomp( name, namelength, "TT:", 3 )
      && namecomp( name, namelength, "tty:", 4 )
      && namecomp( name, namelength, "tt:", 3 )
      && namecomp( name, namelength, "/dev/tty", 8) ) {
#ifdef LEAF
	if (namelength >= maxFileName)
	    invalid(FDB, "OPEN --- too long file name");
	strcpyn (str, name, namelength);
	str[namelength] = 0;
	File(FDB) = fopen (str, (openinput ? "r" : "w+"));
	if (File(FDB) <= 0) {
	    invalid(FDB, "OPEN -- file not found");
	    (FDB->status) = NOTOPEN;
	};
	FDB->ttymode = FALSE;
	FDB->device = LEAFDEV;
	FDB->filetype = ASCIIFILE;
#else
	invalid(FDB, "OPEN -- file name not TTY: or TT:");
	(FDB->status) = NOTOPEN;
#endif
    };

    COMMENT("|***set remaining status flags ");
	(FDB->eofflag) = FALSE;

}

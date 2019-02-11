#include "txtfdb.h"
#include "macros.m"
#ifdef MC68000
_close( FDB )
#else
_close( FDB )
#endif
	struct txtfdb *FDB;
{
	(FDB->status) = NOTOPEN;
#ifdef LEAF
	if (FDB->device == LEAFDEV) fclose(File(FDB));
#endif
}

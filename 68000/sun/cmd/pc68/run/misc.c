#include "txtfdb.h"
#include "macros.m"
#ifdef MC68000
__pdate( day, month, year )
#else
_pdate( day, month, year )
#endif
	int *day, *month, *year;
{
	*day   = 10;
	*month = 12;
	*year  = 81;
}

#ifdef MC68000
__ptime( )
#else
_ptime( )
#endif
{	static int time = 1200;
	return( time++ );
}
#ifdef MC68000
__debug( )
#else
_debug( )
#endif
{}

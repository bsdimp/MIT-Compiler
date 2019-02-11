#include "txtfdb.h"
_wrr (r, FDB, fldw, digits)
    struct txtfdb *FDB;
  {
#ifdef LEAF
    if (FDB->device == LEAFDEV) {
    	if (digits < 0) fprintf( File(FDB), "%*e", fldw, r, 0);
	else fprintf( File(FDB), "%*.*f", fldw, digits, r, 0);
    } else
#endif
    if (digits < 0) printf("%*e", fldw, r, 0);
    else printf("%*.*f", fldw, digits, r, 0);
    FDB->pbuffer = '?';
}

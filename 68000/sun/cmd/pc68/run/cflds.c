#include "txtfdb.h"
_flds (FDB)
struct txtfdb *FDB;
 {
 FDB->status = NOTOPEN;
 FDB->device = ANYDEV;
 FDB->eofflag = 0;
 FDB->bufferinvalid = 0;
 FDB->filetype = BINARY;
 FDB->ttymode = 0;
 FDB->prompt[0] = 'A';
 FDB->eolnflag = 0;
 FDB->eopageflag = 0;
 FDB->channel = 0;
 FDB->pbuffer = 'A';
}

/* LINTLIBRARY */
/*
 * sunbddecode.c
 *
 * Decode a raw boot directory buffer into a human-readable format.
 *
 * Jeffrey Mogul	7 November 1980		18-February-1981
 *	Sun version	8 June 1981
 *
 */

#include <puplib.h>
#include "./sunbfd.h"

#define MAXBFILES 100	/* limit on number of interations */

struct bfblock {	/* what we get in the raw buffer */
	ushort	attributes;	/* attribute bits */
	ushort	bfdate;	/* creation date */
	ushort	_filler;	/* &#$^% C compiler */
	char    bcplname[2];	/* probably longer! */
	};

char *ctime();

sunbddecode(data,dlen,BFD)
char *data;		/* raw boot directory */
int	dlen;		/* length of data */
struct BFDentry *BFD;	/* formatted directory */
{
	struct bfblock *bfp;
	int slen;
	long i;
	char *dp;

	dp = data;

	for (i=0;i<MAXBFILES;i++) {	/* for as many as there are */
		if (dp >= &data[dlen]) break;
		bfp = (struct bfblock *)dp;
		
		/* get bootfile name */
		slen = GetBCPLString(bfp->bcplname,BFD[i].bfd_name);

		if (slen <= 2) break;	/* null name */

		BFD[i].bfd_attributes = bfp->attributes;
			/* get attribute bits */

		BFD[i].bfd_date = getlong(*((long*)&bfp->bfdate));
			/* and creation time in Alto format */

		dp += (slen + 6);
				/* advance data pointer */

		}
	return(i);
}


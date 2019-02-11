/* file globaldefs.h - a rational place for common defines for masks, etc. */

#define	LOBYTE	0377	/* mask to retrieve low byte from a word */
#define LO5BITS 037	/* mask to retrieve low 5 bits from a word */
#define BLOCKSIZE 512	/* basic file system block size (a la BSIZE) */

#ifndef DIRSIZ
#define DIRSIZ 14
#endif

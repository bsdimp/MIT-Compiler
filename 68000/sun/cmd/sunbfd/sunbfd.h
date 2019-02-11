/*
 * sunbfd.h
 *
 * defines structure used in a boot file directory
 */

#define MAXBFDNAME 30	/* maximum length of bootfile name, with 0 */

struct BFDentry { 
	unsigned short bfd_attributes;	/* attribute bits */
	long bfd_date;	/* date of bootfile update */
	char bfd_name[MAXBFDNAME];	/* name of file */
	};

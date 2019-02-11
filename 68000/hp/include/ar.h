/* file ar.h */
#define	ARMAG	0177545
#define	SARMAG	2
/*

#define	ARFMAG	"`\n"
*/

struct ar_hdr {
	long		ar_date;
	long		ar_size;
	short		ar_mode;
	unsigned short	ar_uid;
	unsigned short	ar_gid;
	char		ar_name[14];
};

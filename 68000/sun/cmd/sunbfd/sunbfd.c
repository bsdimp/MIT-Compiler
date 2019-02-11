/*
 * sunbfd.c
 *
 * print boot file directory
 *
 * Jeffrey Mogul	8 June 1981
 */

#include <puplib.h>
#include <pupstatus.h>
#include <UAtimecvt.h>
#include "./sunbfd.h"

#define ALTOBIT 01
#define SUNBIT 010

extern int HostFlags[256];

struct BFDentry bfd[100];

#ifdef MC68000
extern int sp;
main()
{
	sp = 0x1f000;
	submain();
}
submain()
#else
main()
#endif MC68000
{
	struct Port sport;
	char buf[10000];
	char hostname[100];
	int rcode;
	int blen;
	int i;
	int entries;
	long tm;
	int column = 0;

	sport.host = 0;
	sport.net = 0;

	printf("Directory of standard Sun bootfiles:\n");

	rcode = msunbootdir(&sport,buf,&blen);

    	sport.net = HostFlags[0];
	sport.socket = 0;
	printf("Hosts responding: ");
	for (i = 1; i < 256; i++)
	    if (HostFlags[i]) {
		sport.host = i;
		if ((maddtoname(&sport,hostname))==OK) {
		    printf("%s  ",hostname);
		}
		else {
		    PortPrint(&sport);
		    printf("  ");
		}
	    }
	printf("\n");

	entries = sunbddecode(buf,blen,bfd);
	
	bdesort(bfd,entries);

	for (i = 0 ; i < entries; i++ ) {
		tm = AtoUtime(bfd[i].bfd_date);
		/* ignore non-Sun files and duplicates */
		if ( (bfd[i].bfd_attributes&SUNBIT) &&
		     (strcmp(bfd[i].bfd_name,bfd[i+1].bfd_name)) ){
#ifdef CTIME
		    printf("%s %s",
			bfd[i].bfd_name,
			ctime(&tm));
#else
		    printf("%-19s",bfd[i].bfd_name);
		    column++;
		    if (column>3) {
		        column = 0;
			printf("\n");
		    }
#endif
		}
	}
	if (column) printf("\n");
}

bdesort(bfdp,n)
struct BFDentry *bfdp;
int n;
{
	int i;
	int j;
	struct BFDentry temp;
	
	for (i = 1; i <= n; i++) {
	    for (j = 1; j < i; j++) {
	    	if (strcmp(bfdp[i-1].bfd_name,bfdp[j-1].bfd_name) < 0) {
			bmove(&bfdp[i-1],&temp,sizeof(temp));
			bmove(&bfdp[j-1],&bfdp[i-1],sizeof(temp));
			bmove(&temp,&bfdp[j-1],sizeof(temp));
		}
	    }
	}
}

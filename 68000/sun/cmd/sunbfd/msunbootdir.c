/* LINTLIBRARY */
/*
 * msunbootdir.c
 *
 * Get a directory of all possible Sun boot files from the
 * server; this is tricky because the reply may fill multiple
 * packets.  Returns a raw buffer consisting of all of the
 * bytes received.
 *
 * The static array HostFlags contains a boolean for each
 * possible host indicating if it responded.  HostFlags[0]
 * contains the network number of the (last) host to respond.
 *
 * Jeffrey Mogul	7 November 1980	17-February-1981
 *
 */

#define	BOOTDWAIT 10
#define BDNXTWAIT 4
#include <puplib.h>
#include <pupconstants.h>
#include <pupstatus.h>

int HostFlags[256];

msunbootdir(Sport, buffer, buflen)
struct Port *Sport;		/* Port address of server */
char *buffer;			/* address of return buffer */
int *buflen;			/* returned buffer length */
{	/* */
	int retry;
	int i;
	int tlen = 0;
	int totlen = 0;
	int gotfirst = 0;	/* flag true iff we got at least one
				 * reply */
	int retrystart = 0;
	struct	PupChan	bootdchan;
	ushort	bootdid;
	uchar	RetPupType;

	/* 
	 * initializes HostFlags table
	 */
	for (i = 0; i < 256; i++)
		HostFlags[i] = 0;

	/*
	 * generate a unique id for this connection
	 */
	bootdid = UniqueSocket();

	/*
	 * Caller has set host/net in RemPort.  We insure that
	 * that the remote socket is MiscServices.
	 */
	Sport->socket = MISCSERVICES;
	
	if (pupopen(&bootdchan,bootdid, Sport) != OK) return(NOCHAN);

	/*
	 * set timeout and filter for the Pup channel
	 */
	pupsettimeout(&bootdchan, ONESEC);
	pupsetdfilt(&bootdchan,64);	/* set default filter */

	do {	/* get next packet-full of directory */
	    if (gotfirst) retrystart = BOOTDWAIT-BDNXTWAIT;
			/* wait less for subsequent packets */
	    for (retry=retrystart; retry<BOOTDWAIT; retry++) {

		/*
		 * send the request off ...
		 */
		if (!(gotfirst))	/* while no response at all */
		    pupwrite(&bootdchan, SUNBOOTDREQ, bootdid, NULL, 0);

		/*
		 * ... did we get a response?
		 */

		if (pupread(&bootdchan, buffer, &tlen, &RetPupType, NULL,
				NULL, Sport) == TIMEOUT)
				continue;

		break;
	    }
	    if (retry == BOOTDWAIT) break;	/* exit on first timeout */
	    if (RetPupType != SUNBOOTDREP) break;	/* exit on first nasty */

	    /* got a good packet */
	    HostFlags[0] = Sport->net;
	    HostFlags[Sport->host]++;
	    buffer += tlen;
	    totlen += tlen;
	    gotfirst++;		/* inhibit further requests */
	    } while (retry < BOOTDWAIT );

#ifndef MC68000
	pupclose(&bootdchan);
#endif	MC68000

	if (tlen == 0)	/* if nothing came */
		return (TIMEOUT);

	if (RetPupType != SUNBOOTDREP) return (NOTFOUND);

	/* seems to have gotten a response */
	*buflen = totlen;
	return(RetPupType);

}

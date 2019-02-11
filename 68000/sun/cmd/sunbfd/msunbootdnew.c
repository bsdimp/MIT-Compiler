/* LINTLIBRARY */
/*
 * msunbootdnew.c
 *
 * Get a directory of all possible Sun boot files from the
 * server; "new" version which uses EFTP to transfer buffer.
 * Returns a raw buffer consisting of all of the
 * bytes received.
 *
 *
 * Jeffrey Mogul	7 November 1980	17-February-1981
 *	complete re-write using new protocol 14 September 1981
 *
 */

#define	MAXTRIES 4
/*#define	BOOTDWAIT 10
#define BDNXTWAIT 4 */
#include <puplib.h>
#include <pupconstants.h>
#include <pupstatus.h>
#include <eftp.h>


msunbootdnew(Sport, buffer, buflen)
struct Port *Sport;		/* Port address of server */
char *buffer;			/* address of return buffer */
int *buflen;			/* returned buffer length */
{	/* */
	int retry;
/*	int i; */
	int running;
	int tlen = 0;
	int totlen = 0;
	struct	PupChan	*bootdchan;
	struct	EftpChan RespChan;
	ushort	bootdid;

	/*
	 * generate a unique id for this connection
	 */
	bootdid = UniqueSocket();

	/*
	 * Caller has set host/net in RemPort.  We insure that
	 * that the remote socket is MiscServices.
	 */
	Sport->socket = MISCSERVICES;
	
#ifdef	PUP__NNSO
	EfRecOpen(&RespChan, Sport, 3, 0);
#else	PUP__NSO
	EfRecOpen(&RespChan, Sport, 3, 1);
#endif
	
	RespChan.pchan.SrcPort.socket = bootdid;
	RespChan.pchan.DstPort.socket = MISCSERVICES;

	bootdchan = &(RespChan.pchan);
	pupsetdfilt(bootdchan,32);

	for (retry = 0; retry < MAXTRIES; retry++) {
		
	    pupwrite(bootdchan, SUNBOOTDNEW, bootdid, NULL, 0);
			/* request boot directory */

	    running = 1;
	    while (running == 1) {
		switch (EftpRead(&RespChan, buffer, 532, &tlen)) {

		    case OK:
			buffer += tlen;
			totlen += tlen;
			break;

		    case EFTP_ENDOFFILE:
		    	totlen += tlen;
			running = -1;
			break;

		    default:
			running = 0;
			break;
		}
	    }
	    if (running == -1) break;
	}
	EfRecEnd(&RespChan);

	if (running == 0)
		return(TIMEOUT);

#ifndef MC68000
	pupclose(&bootdchan);
#endif	MC68000

	/* seems to have gotten a response */
	*buflen = totlen;
	/* set Sport parameter to address of responding host */
	PortCopy(&(RespChan.remport),Sport);
	return(OK);

}

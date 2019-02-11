/*
 * send.c	SECOND VERSION
 *
 * send a message to a user over the Ethernet.
 * The first argument is the name of the remote host;
 * the second argument is the name of the user.  The maximum
 * message length is about 500 characters; it comes from
 * stdin and is terminated by EOF.
 *
 * Jeffrey Mogul	25-June-1980	10 February 1981
 */

#include <stdio.h>
#include <puplib.h>
#include <pupstatus.h>
#include <pupconstants.h>

#define MAXMSG	500	/* somewhat less than biggest Pup data */

main ()
{
	char hostname[100];
	char username[100];
	char myname[100];
	char msgbuf[MAXMSG];
	char LineBuf[100];
	char *strcpy();
	char *strcat();
	struct Port DstPort;
	int  msize = 0;
	char i;

	printf("Send program - sends message to a Unix user\n");

	query("What is your name? ",myname);
	query("Name of user to receive message? ",username);

gethost:
	query("Host to receive message? ",hostname);

	switch (mlookup(hostname,&DstPort)) {

	    case OK:
		break;

	    case NOTFOUND:
		fprintf(stderr,"[Host %s does not exist.]\n",hostname);
		goto gethost;
	
	    case TIMEOUT:
		fprintf(stderr,"[Name server did not respond.]\n");
		goto gethost;
	
	    default:
		fprintf(stderr,"[No Pup channels available - try again.]\n");
		exit(1);
		};

	if (DstPort.host == 0)
		fprintf(stderr,
			"[Sending broadcast to all hosts on net %o##]\n",
			DstPort.net);

More:	printf("Enter message, maximum of %d characters.  End with CTRL/D\n",
		MAXMSG);
	while (gets(LineBuf) != NULL) {
		if ((strlen(LineBuf) + 1 + strlen(msgbuf)) > MAXMSG) {
			printf("[Message too long - last line not sent.]\n");
			break;
			};
		strcat(LineBuf,"\n");
		strcat(msgbuf,LineBuf);
		}

	switch (msendumsg(myname,username,msgbuf,&DstPort)) {
	
	    case TIMEOUT:
		fprintf(stderr,"[Host %s did not respond - try again.]\n",
				hostname);
		break;
	
	    case SENDUACK:
		fprintf(stderr,"[Message Delivered.]\n");
		break;
	
	    case SENDUERR:
		fprintf(stderr,"[Host %s refused message.]\n",hostname);
		break;
	
	    case NOROUTE:
		fprintf(stderr,"[Can't get to %s from here.]\n",hostname);
		break;

	    default:
		fprintf(stderr,"[No Pup channels available - try again.]\n");
		break;
	    }

	query("More to send? (y/n) ",LineBuf);
	if (*LineBuf == 'y') goto More;

}

query(prompt,buffer)
char *prompt;
char *buffer;
{
	printf(prompt);
	gets(buffer);
}

char PupErrMsg[128];

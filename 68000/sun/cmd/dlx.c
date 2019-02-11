/*
 * dlx.c
 *
 * downloader for modified sun monitor
 *
 * Jeffrey Mogul	16 April 1981
 *
 * modified:
 *	11 August 1981 (jcm) -- added -d flag (debug info)
 *
 *	12 June 1981 (jcm) -- checks that first byte is an 'S',
 *	adds .dl extension if none given and file does not exist,
 *	or file exists but does not start with an 'S'.
 *
 * This is a minor modification of ....
 *
 *		Downloader with Error Correction
			V.R. Pratt
			Mar., 1981

Usage: dlx filename
Intended to be invoked from the Mogul monitor; so precede with l, as in
ldlx filename

The dlx program first does stty cbreak -echo.
It then prints out '\\' followed by some commands that cause echoing of
channel B (host) input on channel A (tty) and send monitor output to channel B
so that dlx can read it.  It then waits for two >'s, which is what the monitor
will send to the host after the channel switch.  Then it sends the records from
the input file.  After sending each record it checks that the response was Y>.

If the response was anything but Y> it assumes the worst and tries to get
everything back into synch.  First it sends BEL (^G) to alert the user that
there has been an error.  Then it sends a unique hex id (starting from 5007e as
it happens, and counting up by 1 for each erroneous record), followed by
return and q (for quit), then looks for this id to be printed out by the
monitor (which it does as part of opening this location).  When the unique id
finally arrives, it skips to the next >, and resends the record.

On exit from dlx, whether caused by interrupt or termination, stty -cbreak echo
is performed, and control is passed back to the monitor via i A.
If the monitor is not working correctly it may be necessary to interrupt dlx
(with ^C) to return to the Vax shell.

The echoing of the text on the user's terminal contains no linefeeds, so that
each record overwrites the preceding one.  If this is unwanted I will change
it.

*/
/*#define DEBUG */
#include <stdio.h>
#include <varargs.h>
#include <signal.h>

FILE *infile, *sunscriptfile, *vaxscriptfile;
FILE *extendopen();

int debug = 0;
int before=0;	/* 0 on first entry to idexit */

char
get()
{char c;
	c=getchar();
	if (debug)
 	    putc(c, sunscriptfile);
 	return c;
}

idexit(n)
{
	before |= n;
	printf("i A+\r");
	/* drop an extraneous '+' into the stream, so that we
	 * can grab it when it gets echoed back
	 */
/*	printf("E 506\r352\rq\ri A\r"); */
	if (!before) {
		before = 1;
		while (get() != '+');
		get();	/* eat cr */
		get();	/* eat lf */
 	}
 	system("stty -cbreak echo");
 	exit(2);
}

/* neither gripe nor formgripe can use a "'" character, since
 * this screws up the shell
 */
gripe(s)
	{printf("\\;    Cannot open %s\n\n\r",s);
	 idexit(1);
	}
formgripe(s)
	{printf("\\;    %s is not in S-record format\n\n\r",s);
	 idexit(1);
	}

main(argc,argv) char **argv;
{char c;
	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
		signal(SIGINT, idexit);
	if (signal(SIGTERM, SIG_IGN) != SIG_IGN)
		signal(SIGTERM, idexit);
	system("stty cbreak -echo");
	if ((argc > 1) && (argv[1][0] == '-')) {
		if (argv[1][1] == 'd') debug++;
		argv++;
		argc--;
	}
	if (argc < 2) {
		printf("\\;    Usage: dlx filename\n\n\r");
		idexit(1);
	}
 	if ((infile = fopen(argv[1],"r")) == NULL)
	    if ((infile = extendopen(argv[1])) == NULL)
		gripe(argv[1]);

	c = getc(infile);
	ungetc(c,infile);

	if (c != 'S') {	/* not an S-record file */
	    /* this may be redundant, but we might have found
	     * a b.out file by mistake */
	    fclose(infile);
	    if ((infile = extendopen(argv[1])) == NULL)
		formgripe(argv[1]);
	    
	    c = getc(infile);
	    ungetc(c,infile);
	    if (c != 'S')
	        formgripe(argv[1]);
	}

	/* ok, infile is open and starts with an 'S' */
	
	if (debug) {
 	    if ((sunscriptfile = fopen("sunscript","w")) == NULL)
		gripe("sunscript");
	    if ((vaxscriptfile = fopen("vaxscript","w")) == NULL)
		gripe("vaxscript");
	}

	printf("\\");	/* send the "start load" character */

	if (debug) {
	    fprintf(vaxscriptfile,"\\");
	}
 	while ((c = get()) != '>');
 	while (record());
 	idexit(0);
}

char buf[100];

record()
{char c, d, *bufpnt = buf; int m,n=125;
	do *bufpnt++ = c = getc(infile); 
    	while (c != EOF & c != '\n');
 	if (c == EOF) return 0;
 	*--bufpnt = '\0';
 	while (1) {
     		printf(buf);
		if (debug)
      		    fprintf(vaxscriptfile, buf);
      		putchar('\r');
		if (debug)
		    putc('\r', vaxscriptfile);
      		while ((c=get()) != '>') d = c;
      		if (d == 'Y') return 1;
		n++;
      		printf("\007\rE %x\rq\r",0x50000+n);
		if (debug)
      		    fprintf(vaxscriptfile, "\007\rE %x\rq\r",0x50000+n);
      		{int i=10000; while (i--);}	/* pause for recovery */
      		while (1) {
      			while (get() != '5');
      	 		scanf("%x",&m);
      	 		if (m == n) break;
		}
      		while (get() != '>');
	}
}

FILE *extendopen(fn)
char *fn;
{
	char *index();
	char *strcat();
	char *strcpy();
	char bigname[100];
	
	if (index(fn,'.') > index(fn,'/')) return(NULL);
	
	strcpy(bigname,fn);
	strcat(bigname,".dl");
	return(fopen(bigname,"r"));
}


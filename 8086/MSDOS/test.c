#include <stdio.h>

long flength();
extern int _dosax,_dosbx,_doscx,_dosdx;

char	buf[200];

extern struct
 {	unsigned envseg;
	char *cmdbuf,*cmdseg;
	char *fcb1, *fcb1seg;
	char *fcb2, *fcb2seg;
 } _pblk;

otest(dev)
 {	int fid = creat(dev, 0);
	fprintf(stderr, "creat(%s, 0) = %d\r\n", dev, fid);
	if (fid < 0) return;
	write(fid, "Hello!\r\n", 8);
	close(fid);
 }

main(argc, argv)
 char **argv;
 {	char ch, *cmd;
	int fid, i;
	long leng;

	otest("CON:");
	otest("CON");
	otest("FOO");
	otest("/DEV/CON:");
	otest("/DEV/CON");
	otest("/dev/con");

	fprintf(stderr, "Environment:\r\n");
	for (i=0;;i++)
	 { _genv(i, buf);
	   if (!buf[0]) break;
	   fprintf(stderr, " %d: '%s'\r\n", i, buf);
	 }

	if (argc>1) cmd = argv[1];
	else cmd = 0;
	if (cmd) fprintf(stderr, "About to execute '%s':\r\n", cmd);
	else fprintf(stderr, "About to execute system(0)\r\n");
	system(cmd);
 }

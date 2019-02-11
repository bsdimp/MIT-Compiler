/*
 * cc68 - front end for MC68000 C compiler
 *
 * Jeffrey Mogul @ Stanford	February 10 1981
 * 	- hacked up from cc.c
 *
 * V. Pratt March 1981
 * 	-v (version), -d (dl68), -r (rev68) options
 *
 * Bill Nowicki February 1982
 *	- Changed exec's with full pathnames to use search path
 *	- "-ifilename" option added to substitute file for crt0.b
 *	- Merged Pratt's "single module" check of Januray 1982
 *	- Merged in Mogul's undocumented .ls hack
 *	- Merged in Pratt's "-u" hack
 *
 * March 1982 (jcm, vrp, win)
 *	- Fixed bug regarding linking a single .b file
 *	- Removed Jeff's ANNOYING #ifdef
 *	- Added -vL for LucasFilms "temporary" kludge
 *	- files with no suffix assumed to be b.out format
 *	- Changed back to absolute path names (sigh)
 */

#include <sys/types.h>
#include <stdio.h>
#include <ctype.h>
#include <signal.h>
#include <dir.h>


# define LucasKludge "/mnt/lunix/bin/"
# define BinDirectory "/usr/local/bin/"

char	*cpp = "/lib/cpp";	/* C preprocessor */
char	*ccom = "ccom68";	/* Johnson's portable C compiler */
char	*c2 = "c268";		/* Terman's .s->.s optimizer */
char	*as = "as68";		/* Patrick's 68k assembler */
char	*ld = "ld68";		/* 68k link editor */
char	*dl = "dl68";		/* MACSBUG downloader */
char	*rev = "rev68";		/* Pratt's .b 68k reformatter */
				/* run-time start-up */
char	*crt0 = "/usr/sun/lib/crtsun.b";
char	*sunincludes = "-I/usr/sun/include";
char	*dmincludes = "-I/usr/sun/dm/include";
char	*defines = "-DMC68000";	/* tell cpp this is a 68000 */

char	tmp0[30];		/* big enough for /tmp/ctm%05.5d */
char	*tmp1, *tmp2, *tmp3, *tmp4, *tmp5;
char	*infile=0, *outfile=0;
char	*savestr(), *strspl(), *setsuf(), *setlongsuf();
char	*type;
int	idexit();
char	**av, **clist, **llist, **flist, **ulist, **plist;
int	cflag=0, 	/* skip link editing, result is filename.b */
	dflag=0,	/* 1 -> apply dl68 to yield filename.d */
	eflag=0, 	/* error flag; records errors */
	gflag=0, 	/* 1 -> ccom68 generates info for sdb68 (nonexistent)*/
	lflag=0,	/* 1 -> as68 generates listing */
	oflag=0, 	/* optimization flag; 1 -> invoke o68 */
	pflag=0,	/* 1 -> don't delete temporary files */
	rflag=0,	/* 1 -> apply rev68 to yield filename.r */
	Rflag=0,	/* 1 -> ld68 preserves relocation bits */
	sflag=0,  	/* 1 -> skip assembly, result is filename.s */
	wflag=0,  	/* -w flag passed to ccom68 */
	zflag=0,	/* print exec() trace */
	exflag=0, 	/* 1 -> only apply cpp, result to stdout */
	noxflag=0,	/* 1 -> -x flag off -> output local symbols */
	proflag=0;	/* profile flag: generate jbsr mcount for each fctn */
int	
	exfail;
char	*chpass=0,
	*version=0,	/* version: -vm, -v1, -v2, ... */
	*Torg=0,	/* Text origin */
	*entrypt=0,	/* entry point */
	*npassname=0;

int	nc=0, 	/* no of programs for ccom */
	nl=0, 	/* no of .b inputs for ld (including libraries) */
	nm=0,	/* no of modules (excluding libraries) */
	nf=0,	/* no of flags for ld68 */
	nu=0,	/* no of files of unknown type */
	np=0, 	/* no of args for cpp */
	na=0;	/* no of args to each callsys */

#define	cunlink(s)	if (s&&!zflag) unlink(s)

main(argc, argv)
	char **argv;
{
	char *t;
	char *assource;
	int i, j, c;

	/* ld currently adds upto 5 args; 20 is room to spare */
	/* [Does this apply to ld68?  - pratt] */
	av = (char **)calloc(argc+20, sizeof (char **));
	clist = (char **)calloc(argc, sizeof (char **));
	llist = (char **)calloc(argc, sizeof (char **));
	flist = (char **)calloc(argc, sizeof (char **));
	ulist = (char **)calloc(argc, sizeof (char **));
	plist = (char **)calloc(argc, sizeof (char **));
	for (i = 1; i < argc; i++) {
		if (*argv[i] == '-') switch (argv[i][1]) {

		case '-':	/* negate some default */
			switch(argv[i][2]) 
			  {
				case 'x':
					noxflag++;
					break;
		    	  }
			break;

		case 'S':
			sflag++;
			cflag++;
			break;

		case 'e':
			if (++i < argc)
				entrypt = argv[i];
			break;
		case 'o':
			if (++i < argc) {
				outfile = argv[i];
				switch (getsuf(outfile)) {

				case 'c':
					error("-o would overwrite %s",
					    outfile);
					exit(8);
				}
			}
			break;
		case 'T':
			if (++i < argc) 
				Torg = argv[i];
			break;
		case 'u':
			if (++i < argc) {
				llist[nl++] = "-u";
				llist[nl++] = argv[i];
			}
			break;
		case 'O':
			oflag++;
			break;
		case 'p':
			proflag++;
			break;
		case 'g':
			gflag++;
			break;
		case 'L':			/* WIN */
			lflag++;
			break;
		case 'w':
			wflag++;
			break;
		case 'E':
			exflag++;
		case 'P':
			pflag++;
			if (argv[i][1]=='P')
				fprintf(stderr,
	"cc68: warning: -P option obsolete; you should use -E instead\n");
			plist[np++] = argv[i];
			break;
		case 'c':
			cflag++;
			break;
		case 'd':
			dflag++;
			break;
		case 'r':
			rflag++;
			break;
		case 'R':
			Rflag++;
			break;
		case 'D':
		case 'I':
		case 'U':
		case 'C':
			plist[np++] = argv[i];
			break;
		case 't':
			if (chpass)
				error("-t overwrites earlier option", 0);
			chpass = argv[i]+2;
			if (chpass[0]==0)
				chpass = "012p";
			break;
		case 'B':
			if (npassname)
				error("-B overwrites earlier option", 0);
			npassname = argv[i]+2;
			if (npassname[0]==0)
				npassname = "/usr/c/o";
			break;
		case 'l':
			llist[nl++] = argv[i];/* NOT flist, order matters! */
			break;
		case 'v':
			version = argv[i];
			break;
		case 'i':
			crt0 = argv[i]+2;
			break;
		case 'z':	/* trace exec() calls */
			zflag++;
			break;
		default:
			flist[nf++] = argv[i];
			break;
		}
		else {			/* not a flag */
			t = argv[i];
			c = getsuf(t);
			if (c=='c' || c=='s' || exflag) {
				clist[nc++] = t;
				t = setsuf(t, 'b');
				c = 'b';
			}
			if (c=='a' || c=='b') 
			  {
				if (nodup(llist, t))
				  {
					llist[nl++] = t;
					nm++;	/* count programs */
				  }
			  }
			else if (!strcmp(t,"b.out") || !index(t,'.') )
				infile = t;
			else {
				ulist[nu++] = t; /* Unrecognized suffix */
				nm++;
			}
		}
	}	/* End of loop to process arguments */
	for (i=0; i<nu; i++) {
		if (exflag||sflag||cflag) {
			clist[nc++] = ulist[i];
			type = "C code (type .c)";
		}
		else if (dflag||rflag) {
			infile = ulist[i];
			type = "b.out format";
		} 
		else {
			llist[nl++] = ulist[i];
		       	type = "relocatable binary (type .b)";
		}

		fprintf(stderr,
		       "cc68: warning: %s has unrecognized suffix, taken to be %s\n",
		       infile,type);
	}
	if (version && version[2]=='m') crt0 = "/usr/sun/lib/crt0.b";
	if (!nl && !infile) {
		fprintf(stderr,"cc68: no input specified\n");
		exit(8);
	}
	if ((eflag||sflag||cflag) && (dflag || rflag)) {
		fprintf(stderr,"cc68: warning: -E,-S,-c disable -d,-r\n");
		dflag = 0;
		rflag = 0;
	}
	if (gflag) {
		if (oflag)
			fprintf(stderr, "cc68: warning: -g disables -O\n");
		oflag = 0;
	}
	if (npassname && chpass ==0)
		chpass = "012p";
	if (chpass && npassname==0)
		npassname = "/usr/new";
	if (chpass)
	for (t=chpass; *t; t++) {
		switch (*t) {

		case '0':
			ccom = strspl(npassname, "ccom");
			continue;
		case '2':
			c2 = strspl(npassname, "c2");
			continue;
		case 'p':
			cpp = strspl(npassname, "cpp");
			continue;
		}
	}
	if (proflag)
		crt0 = "/usr/sun/lib/mcrt0.b";
	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
		signal(SIGINT, idexit);
	if (signal(SIGTERM, SIG_IGN) != SIG_IGN)
		signal(SIGTERM, idexit);
	if (pflag==0)
		sprintf(tmp0, "/tmp/ctm%05.5d", getpid());
	tmp1 = strspl(tmp0, "1");
	if (nc==0)
		goto nocom;
	tmp2 = strspl(tmp0, "2");
	tmp3 = strspl(tmp0, "3");
	if (pflag==0)
		tmp4 = strspl(tmp0, "4");
	if (oflag)
		tmp5 = strspl(tmp0, "5");
	for (i=0; i<nc; i++) {
		if (nc > 1) {
			printf("%s:\n", clist[i]);
			fflush(stdout);
		}
		if (getsuf(clist[i]) == 's') {
			assource = clist[i];
			goto assemble;		/* thereby skipping ccom68 */
		} else
			assource = tmp3;
		if (pflag)
			tmp4 = setsuf(clist[i], 'i');
		av[0] = "cpp"; av[1] = clist[i]; av[2] = exflag ? "-" : tmp4;
		na = 3;
		for (j = 0; j < np; j++)
			av[na++] = plist[j];
		if (version)
			if (strcmp(version,"-vm") == 0)
				av[na++] = dmincludes;
		av[na++]=sunincludes;
		av[na++]=defines;
		av[na++] = 0;
		if (callsys(cpp, av)) {
			exfail++;
			eflag++;
		}
		if (pflag || exfail) {
			cflag++;
			continue;
		}
		if (sflag)
			assource = tmp3 = setsuf(clist[i], 's');
		av[0] = "ccom"; av[1] = tmp4; av[2] = oflag?tmp5:tmp3; na = 3;
		if (proflag)
			av[na++] = "-XP";
		if (gflag)
			av[na++] = "-Xg";
		if (wflag)
			av[na++] = "-w";
		av[na] = 0;
/*		if (callsys(ccom, av)) {
			cflag++;
			eflag++;
			continue;
		} */
		{ /* this is a hack.  */
		char command[100];
		sprintf(command,"%s <%s >%s",ccom,av[1],av[2]);
		if (zflag) printf( "\t%s\n", command );
		if(system(command)) {
		    eflag++;
		    continue;
		    }
		}
		if (oflag) {
			av[0] = "c2"; av[1] = tmp5; av[2] = tmp3; av[3] = 0;
			if (callsys(c2, av)) {
				unlink(tmp3);
				tmp3 = assource = tmp5;
			} else
				unlink(tmp5);
		}
		if (sflag)
			continue;
	assemble:
		cunlink(tmp1); cunlink(tmp2); cunlink(tmp4);
		na = 0;
		av[na++] = "as68"; 
		av[na++] = "-o"; 
		if (cflag && nc == 1 && outfile)
			av[na++] = outfile;
		else av[na++] = setsuf(clist[i], 'b');
		av[na++] = "-g";	/* permits undefined symbols in as68 */
		if (lflag) {
			av[na++] = "-L";
			av[na++] = setlongsuf(clist[i], "ls");
		}
		av[na++] = assource;
		av[na] = 0;
		if (callsys(as, av) > 1) {
			cflag++;
			eflag++;
			continue;
		}
	}		/* End of loop to produce .b files */

nocom:			/* link edit files in llist[0:nl-1] */
	if (cflag==0 && nl!=0) {
		na = 0;
		av[na++] = "ld";
		av[na++] = "-X";
		if (Rflag)
			av[na++] = "-r";
		if (version)
			av[na++] = version;
		if (entrypt) {
			av[na++] = "-e";
			av[na++] = entrypt;
		}
		if (Torg) {
			av[na++] = "-T";
			av[na++] = Torg;
		}
		av[na++] = crt0;	/* startup */
		if (dflag || rflag) {	/* if dl or rev then just output to */
			av[na++] = "-o";/* temporary file */
			av[na++] = infile = tmp1;
		}
		else if (outfile) {	/* else if outfile exists then */
			av[na++] = "-o";/* output to it.  Default is b.out */
			av[na++] = outfile;
		}
		for (i=0; i<nf; i++)	/* supply all flags */
			av[na++] = flist[i];
		for (i=0; i<nl; i++)	/* supply all .b arguments */
			av[na++] = llist[i];
		if (gflag)
			av[na++] = "-lg";
		av[na++] = "-lc";	/* libc.a always used */
		if (!noxflag)	       /* add -x by default unless --x given */
			av[na++] = "-x";
		av[na++] = 0;			/* argument delimiter */
		eflag |= callsys(ld, av);	/* invoke ld68 */

		if (nc==1 && nm==1 && eflag==0)
		    /*
		     * If we have only one module AND it was compiled
		     * (as opposed to just linked) then remove the .b file.
		     */
			unlink(setsuf(clist[0], 'b'));
	}

dnload:
	if (dflag && eflag==0) {
		na = 0;
		av[na++] = "dl";
		av[na++] = infile;
		if (version)
			av[na++] = version;
		if (Torg) {
			av[na++] = "-T";
			av[na++] = Torg;
		}
		av[na++] = "-o";
		av[na++] = outfile?	outfile:
			   nl?		strspl(setsuf(llist[0],'d'),"l"):
			   		"d.out";
		av[na++] = 0;
		eflag |= callsys(dl, av);	/* invoke dl68 */
	}

reverse:
	if (rflag && eflag==0) {
		na = 0;
		av[na++] = "rev";
		av[na++] = infile;
		av[na++] = outfile && !dflag?	outfile:
			   nl?			setsuf(llist[0],'r'):
			   			"r.out";
		av[na++] = 0;
		eflag |= callsys(rev, av);
	}

	dexit();
}

idexit()
{

	eflag = 100;
	dexit();
}

dexit()
{

	if (!pflag) {
		cunlink(tmp1);
		cunlink(tmp2);
		if (sflag==0)
			cunlink(tmp3);
		cunlink(tmp4);
		cunlink(tmp5);
	}
	exit(eflag);
}

error(s, x)
	char *s, *x;
{
	FILE *diag = exflag ? stderr : stdout;

	fprintf(diag, "cc68: ");
	fprintf(diag, s, x);
	putc('\n', diag);
	exfail++;
	cflag++;
	eflag++;
}

getsuf(as)
char as[];
{
	register int c;
	register char *s;
	register int t;

	s = as;
	c = 0;
	while (t = *s++)
		if (t=='/')
			c = 0;
		else
			c++;
	s -= 3;
	if (c <= DIRSIZ && c > 2 && *s++ == '.')
		return (*s);
	return (0);
}

char *
setsuf(as, ch)
	char *as;
{
	register char *s, *s1;

	s = s1 = savestr(as);
	while (*s)
		if (*s++ == '/')
			s1 = s;
	s[-1] = ch;
	return (s1);
}

char *
setlongsuf(as, suff)
char *as;
char *suff;
{
	register char *s, *s1;
	register int suflen = strlen(suff);

	s = s1 = savestr(as);
	while (*s)
		if (*s++ == '/')
			s1 = s;
	s[-1] = 0;
	if (strlen(s1) > (DIRSIZ - suflen)) {
		s[-suflen] = 0;
		s[-(suflen-1)] = '.';
	}
	return(strspl(s1,suff));
}


callsys(f, v)
	char *f, **v;
{
	int t, status;
	char cmd[256];
	
	if (version && version[2]=='L' && *f!='/')
	  {
	  	/*
		 * We substitute the LucasFilms versions of the loader,
		 * compiler, assembler, etc. if the -vL option was set,
		 * and we have an unqualified pathname.
		 */
	    strcpy( cmd, LucasKludge);
	    strcat( cmd, f);
	  }
	 else if (*f!='/')
	   {
	       /*
	        * add the binary directory at the begining if not
		* already specified, so you can have other versions
		* in your path without screwing up.
		*/
	    strcpy( cmd, BinDirectory);
	    strcat( cmd, f);
	   }
	 else strcpy( cmd, f);

	if (zflag) 
	  {
	  	/*
		 * print out a trace of all commands executed
		 */
	    char **arg = v+1;
	    printf( "\t%s ", cmd);
	    while (*arg) printf( "%s ", *arg++);
	    printf("\n");
	  }
	t = vfork();
	if (t == -1) {
		printf("No more processes\n");
		return (100);
	}
	if (t == 0) {
		execvp( cmd, v);
		printf("Can't find %s\n", cmd);
		fflush(stdout);
		_exit(100);
	}
	while (t != wait(&status))
		;
	if ((t=(status&0377)) != 0 && t!=14) {
		if (t!=2) {
			printf("Fatal error in %s\n", cmd);
			eflag = 8;
		}
		dexit();
	}
	return ((status>>8) & 0377);
}

nodup(l, os)
	char **l, *os;
{
	register char *t, *s;
	register int c;

	s = os;
	if (getsuf(s) != 'b')
		return (1);
	while (t = *l++) {
		while (c = *s++)
			if (c != *t++)
				break;
		if (*t==0 && c==0)
			return (0);
		s = os;
	}
	return (1);
}

#define	NSAVETAB	1024
char	*savetab;
int	saveleft;

char *
savestr(cp)
	register char *cp;
{
	register int len;

	len = strlen(cp) + 1;
	if (len > saveleft) {
		saveleft = NSAVETAB;
		if (len > saveleft)
			saveleft = len;
		savetab = (char *)malloc(saveleft);
		if (savetab == 0) {
			fprintf(stderr, "ran out of memory (savestr)\n");
			exit(1);
		}
	}
	strncpy(savetab, cp, len);
	cp = savetab;
	savetab += len;
	saveleft -= len;
	return (cp);
}

char *
strspl(left, right)
	char *left, *right;
{
	char buf[BUFSIZ];

	strcpy(buf, left);
	strcat(buf, right);
	return (savestr(buf));
}


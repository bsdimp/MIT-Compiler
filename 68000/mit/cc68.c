# include <stdio.h>
# include <ctype.h>
# include <signal.h>

/* cc command */

# define MAXINC 10
# define MAXFIL 100
# define MAXLIB 100
# define MAXOPT 200
char	*tmp0;
char	*tmp1;
char	*tmp2;
char	*tmp3;
char	*tmp4;
char	*tmp5;
char	*outfile;
# define CHSPACE 1000
char	ts[CHSPACE+50];
char	*tsa = ts;
char	*tsp = ts;
char	*av[50];
char	*clist[MAXFIL];
char	*llist[MAXLIB];
int	pflag;
int	sflag;
int	cflag;
int	eflag;
int	exflag;
int	oflag;
int	proflag;
int	noflflag;
int	mxflag;
char	*chpass ;
char	*npassname ;
char	pass0[64] = "/lib/c68";
char	pass1[64] = "/lib/o68";
char	pass2[64] = "/lib/xxx";
char	passp[64] = "/lib/cpp";
char	libdr[64];
char	*ldrel = NULL;	/* -R argument for loader */
# ifndef mc68000	/* PDP11 or VAX11/780	*/
char	pref[64]  = "/projects/nunix/lib/crt0.b";
char	incld[64] = "-I/projects/nunix/include";
char	*a68 = "/usr/local/a68";
char	*ld68 = "/usr/local/ld68";
# else			/* NU-MACHINE		*/
char	pref[64]  = "/lib/crt0.b";
char	incld[64] = "-I/usr/include";
char	*a68 = "/bin/a68";
char	*ld68 = "/bin/ld68";
# endif
char	*copy();
char	*getsuf();
char	*setsuf();
char	*strcat();
char	*strcpy();

main(argc, argv)
char *argv[]; 
{
	char *t;
	char *savetsp;
	char *assource;
	char **pv, *ptemp[MAXOPT], **pvt;
	char *s;
	int nc, nl, i, j, c, nxo, na;
	int idexit();

	pv = ptemp;
	i = nc = nl = nxo = 0;
	setbuf(stdout, (char *)NULL);

	while(++i < argc) {
		if(*argv[i] == '-') switch (argv[i][1]) {
		default:
			goto passa;
		case 'S':
			sflag++;
			cflag++;
			break;
		case 'R':
			if (++i < argc)
				ldrel = argv[i];
			break;
		case 'o':
			if (++i < argc) {
				outfile = argv[i];
				if (strcmp((s = getsuf(outfile)), "c") == 0 ||
				    strcmp(s, "b") == 0 ||
				    strcmp(s, "a68") == 0) {
					error("Would overwrite %s", outfile);
					exit(8);
				}
			}
			break;
		case 'O':
			oflag++;
			break;
		case 'p':
			proflag++;
			break;
		case 'E':
			exflag++;
		case 'P':
			pflag++;
			*pv++ = argv[i];
		case 'c':
			cflag++;
			break;

		case 'f':
			noflflag++;
			break;

		case 'D':
		case 'I':
		case 'U':
		case 'C':
			*pv++ = argv[i];
			if (pv >= ptemp+MAXOPT) {
				error("Too many DIUC options", (char *)NULL);
				--pv;
			}
			break;
		case 't':
			for (t=argv[i]+2; *t; t++) {
				switch (*t) {
				case '0':
					strcpy (pass0, npassname);
					strcat (pass0, "c68");
					continue;
				case '1':
					strcpy (pass1, npassname);
					strcat (pass1, "o68");
					continue;
				case '2':
					strcpy (pass2, npassname);
					strcat (pass2, "xxx");
					continue;
				case 'p':
					strcpy (passp, npassname);
					strcat (passp, "cpp");
					continue;
				case 'c':
					strcpy (pref, npassname);
					strcat (pref, "crt0.b");
					continue;
				case 'i':
					strcpy (incld, npassname);
					strcat (incld, "include");
					continue;
				case 'l':
					strcpy (libdr, npassname);
					strcat (libdr, "lib");
					continue;
				}
			}
			break;

		case 'B':
			if (npassname)
				error("-B overwrites earlier option", (char *)NULL);
			npassname = argv[i]+2;
			if (npassname[0]==0)
				npassname = "/projects/nunix/src/cmd/c/o";
			break;
		} 
		else {
passa:
			t = argv[i];
			if(strcmp((s = getsuf(t)), "c") == 0 ||
			   strcmp(s, "a68") == 0 ||
			   exflag) {
				clist[nc++] = t;
				if (nc>=MAXFIL) {
					error("Too many source files", (char *)NULL);
					exit(1);
				}
				t = setsuf(t, "b");
			}
			if (nodup(llist, t)) {
				llist[nl++] = t;
				if (nl >= MAXLIB) {
					error("Too many object/library files", (char *)NULL);
					exit(1);
				}
				if (strcmp(getsuf(t), "b") == 0)
					nxo++;
			}
		}
	}

	*pv++ = "-Updp11";
	*pv++ = "-Uvax";
	*pv++ = "-Dmc68000";
	*pv++ = incld;

	if (noflflag)
		strcpy (pref, proflag ? "/lib/fmcrt0.b" : "/lib/fcrt0.b");
	else if (proflag)
		strcpy (pref, "/lib/mcrt0.b");
	if(nc==0)
		goto nocom;
	if (pflag==0) {
		tmp0 = copy("/tmp/ctm0a");
		while (access(tmp0, 0)==0)
			tmp0[9]++;
		while((creat(tmp0, 0400))<0) {
			if (tmp0[9]=='z') {
				error("cc: cannot create temp", NULL);
				exit(1);
			}
			tmp0[9]++;
		}
	}
	if (signal(SIGINT, SIG_IGN) != SIG_IGN)
		signal(SIGINT, idexit);
	if (signal(SIGTERM, SIG_IGN) != SIG_IGN)
		signal(SIGTERM, idexit);
	(tmp1 = copy(tmp0))[8] = '1';
	(tmp2 = copy(tmp0))[8] = '2';
	(tmp3 = copy(tmp0))[8] = '3';
	strcat(tmp3, ".a68");
	if (oflag)
		(tmp5 = copy(tmp0))[8] = '5';
	if (pflag==0)
		(tmp4 = copy(tmp0))[8] = '4';
	pvt = pv;
	for (i=0; i<nc; i++) {
		if (nc>1)
			printf("%s:\n", clist[i]);
		if (strcmp(getsuf(clist[i]), "a68") == 0) {
			assource = clist[i];
			goto assemble;
		} 
		else
			assource = tmp3;
		if (pflag)
			tmp4 = setsuf(clist[i], "i");
		savetsp = tsp;

		av[0] = "cpp";
		av[1] = clist[i];
		av[2] = exflag ? "-" : tmp4;
		na = 3;
		for(pv=ptemp; pv <pvt; pv++)
			av[na++] = *pv;
		av[na++]=0;
		if (callsys(passp, av, 0, 0)) {
			cflag++;
			eflag++;
			continue;
		}
		tsp = savetsp;

		av[0]= "c68";
		if (pflag) {
			cflag++;
			continue;
		}
		j = 1;
		if (proflag)
			av[j++] = "-Xp";
		if (noflflag)
		    av[j++] = "-f";
		av[j++] = 0;
		if (sflag)
		    assource = tmp3 = setsuf(clist[i], "a68");
		if (callsys(pass0, av, tmp4, oflag ? tmp5 : tmp3)) {
			cflag++;
			eflag++;
			continue;
		}
		unlink(tmp4);

		if (oflag) {
		    av[0] = "o68";
		    av[1] = 0;
		    if (sflag)
			assource = tmp3 = setsuf(clist[i], "a68");
		    if(callsys(pass1, av, tmp5, tmp3)) {
			cflag++;
			eflag++;
			continue;
		    }
		}

		if (sflag)
			continue;
assemble:
		av[0] = "a68";
		av[1] = "-c";
		av[2] = "-o";
		av[3] = setsuf(clist[i], "b");
		av[4] = assource;
		av[5] = 0;
		cunlink(tmp1);
		cunlink(tmp2);
		cunlink(tmp4);
		if (callsys(a68, av, 0, 0) > 1) {
			cflag++;
			eflag++;
			continue;
		}
		cunlink(tmp3);
	}

nocom:
	if (cflag==0 && nl!=0) {
		i = 0;
		av[0] = "ld68";
		av[1] = "-x";
		av[2] = pref;
		av[3] = "-R";
		if(ldrel != NULL)
			av[4] = ldrel;
		else
			av[4] = "400";
		j = 5;

		if (outfile) {
			av[j++] = "-o";
			av[j++] = outfile;
		}
		if (libdr[0]) {
			av[j++] = "-L";
			av[j++] = libdr;
		}
		while(i<nl) {
			av[j++] = llist[i++];
		}
		av[j++] = "-lc";
		av[j++] = 0;
		eflag |= callsys(ld68, av, 0, 0);
		if (nc==1 && nxo==1 && eflag==0)
			cunlink(setsuf(clist[0], "b"));
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
		cunlink(tmp0);
	}
	exit(eflag);
}

error(s, x)
char *s, *x;
{
	fprintf(exflag?stderr:stdout, s, x);
	putc('\n', exflag? stderr : stdout);
	cflag++;
	eflag++;
}




char *
getsuf(s)
register char *s;
{
	register int c;
	register char *sf = "";
	register int t;

	c = 0;
	while(t = *s++) {
		if (t=='/') {
			sf = "";
			c = 0;
			continue;
		}
		else if (t=='.')
			sf = s;
		c++;
	}
	if (c<=14 && c>2)
		return(sf);
	return("");
}

char *
setsuf(as, cp)
char *as, *cp;
{
	register char *s, *s1, *s2 = NULL;

	s = s1 = copy(as);
	while(*s)
		if (*s == '/') {
			s1 = ++s;
			s2 = NULL;
		}
		else if (*s == '.')
			s2 = ++s;
		else
			++s;
	if(s2 == NULL) {
		s2 = s;
		*s2++ = '.';
	}
	do
	    *s2++ = *cp; 
	while (*cp++);
	return(s1);
}


xopen(fp, m)
char *fp;
{
int	fd;

    switch (m) {
    case 0:
	return(open(fp, 0));
	break;
    case 1:
	return(creat(fp, 0666));
	break;
    case 2:
	if ( (fd = creat(fp, 0666)) < 0)
	    return(fd);
	close(fd);
	return(open(fp, 0));
	break;
    }
}


callsys(f, v, si, so)
char f[], *v[]; 
char	*si, *so;
{
	int t, status;

	if ((t=fork())==0) {
		if (si) {
		    close(0);
		    if (xopen(si, 0) < 0) {
			fprintf(stderr, "couldn't open %s\n", si);
			exit(100);
		    }
		}
		if (so) {
		    close(1);
		    if (xopen(so, 1) < 0) {
			fprintf(stderr, "couldn't open %s\n", so);
			exit(100);
		    }
		}
		execv(f, v);
		fprintf(stderr, "Can't find %s\n", f);
		exit(100);
	} else
		if (t == -1) {
			printf("Try again\n");
			return(100);
		}
	while(t!=wait(&status))
		;
	if (t = status&0377) {
		if (t!=SIGINT) {
			printf("Fatal error in %s\n", f);
			eflag = 8;
		}
		dexit();
	}
	return((status>>8) & 0377);
}

char *
copy(as)
char *as;
{
	char *malloc();
	register char *otsp, *s;

	otsp = tsp;
	s = as;
	while (*tsp++ = *s++)
		;
	tsp += 4;	/* really only need 2 ; hack for things like .a68 */
	if (tsp > tsa+CHSPACE) {
		tsp = tsa = malloc(CHSPACE+50);
		if (tsp==NULL) {
			error("no space for file names", (char *)NULL);
			dexit();
		}
	}
	return(otsp);
}

nodup(l, os)
char **l, *os;
{
	register char *t, *s;
	register int c;

	s = os;
	if (strcmp(getsuf(s), "b") == 0)
		return(1);
	while(t = *l++) {
		while(c = *s++)
			if (c != *t++)
				break;
		if (*t=='\0' && c=='\0')
			return(0);
		s = os;
	}
	return(1);
}

cunlink(f)
char *f;
{
	if (f==NULL)
		return;
	unlink(f);
}


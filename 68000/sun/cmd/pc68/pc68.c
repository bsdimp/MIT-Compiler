/*
 ****************************************************************************
 *
 * Pc68 - front end for the portable Pascal* compiler, 68000 target machine.
 *        pieces stolen from cc68.c, pc.c, and cc.c.
 *	  Jim Archer - Stanford   (Archer@Score)
 *	  currenly maintained by Per Bothner (bothner@su-score)
 *	  in progress
 *
 ****************************************************************************
 */
#include <stdio.h>
#include <signal.h>
#include <wait.h>

/* It's unclear whether the extension for assembler files should be
 * ".a68" or ".s", so you can easily change it: */
#define asSuffix	"s"

#define UNIMPLEMENTED(x) fprintf(stderr, "pc68: not yet implemented '%s'\n",x)
#define EQ(s1,s2)	(strcmp(s1,s2)==0)

/*  program names for each of the stages of the compilation */
#include "files.h"

/*  essential component locations for loader */
    char	*crt0 = "/usr/sun/lib/crtsun.b";/* run-time start-up */
    char	*infile        = 0;
    char	*outfile       = 0;
    char        *version       = 0;
    char        *textorigin    = 0;
    char        *entrypoint    = 0;

/*  lists for building parameters for system programs */
    char  **argvalue;	/* argument list workarea for program passes */
    char  **compile;	/* list of program names to be compiled      */
    char  **assemble;	/* list of program names to be assembled     */
    char  **load;	/* list of progam names to be loaded         */
    char  **loadflags;	/* list of progam names to be loaded         */
    char  **delete;     /* list of files to be deleted               */

/*  list counts for parameter lists */
    int	  compile_count, assemble_count, load_count, flag_count, delete_count;

/*  flags used to control compilation process */
    int   Sflag=0;	/* skip assembly; generate .s               */
    int   sflag=0;      /* check pascal standards                   */
    int   noxflag=0;	/* don't output local symbols               */
    int   cflag=0;	/* compile only, omit linkage 		    */
    int   Rflag=0;	/* save relocation flags in b.out           */
    int   Uflag=0;	/* save ucode in filename.u		    */
    int   Oflag=0;	/* invoke object optimizer	            */
    int   Wflag=0;	/* invoke ucode-to-ucode optimizer	    */
    int   gflag=0;	/* provide hooks for debugger		    */
    int   wflag=0;	/* suppress warnings			    */
    int   exflag=0;	/* run only preprocessor		    */
    int   Lflag=0;      /* put assembler listing in file.slist      */
    int   dflag=0;      /* use dl68 to create filename.d            */
    int   rflag=0;      /* use rev68 to create filename.r           */
    int   eflag=0;      /* error count for aborting further work    */
    int   Pflag=0;      /* don't delete temporary files             */
    int   pflag=0;	/* save Pascal listing even if no errors    */

char	*mymktemp();

char	*addsuf(), *trimsuf(), *getsuf(), *setsuf(), *savestr();

int	debug = 0;

int	pc1errs, pc2errs, errs;

int	onintr();

main(argc, argv)
    int argc;
    char **argv;
{
    register char *argp;
    register int   argcount;
    register int i;
    int savargx;
    char *t, *suf, *list, c, *ucodefile, *memdef, *itemp, 
         *utemp, *Utemp, *opt, *optlist;
    int j;

    /*  make sure there is something to do */
        if (argc <= 1) 
        {   execl("/usr/ucb/more", "oops", help);
	    exit(1);
        }

    /*  set up to catch errors and exit */
        if (signal(SIGINT, SIG_IGN) != SIG_IGN) 
        {   signal(SIGINT, onintr);
	    signal(SIGTERM, onintr);
        }

    /*  allocate name/parameter lists */
	argvalue  = (char **)calloc(argc+10,   sizeof (char **));
	compile   = (char **)calloc(argc+5,    sizeof (char **));
	assemble  = (char **)calloc(argc+5,    sizeof (char **));
	load      = (char **)calloc(argc+5,    sizeof (char **));
	loadflags = (char **)calloc(argc+5,    sizeof (char **));
	delete    = (char **)calloc(5*argc+10, sizeof (char **));
	compile_count = assemble_count 
                      = load_count 
                      = flag_count 
                      = delete_count = 0;

    /*  for each parameter, save value or intent */
	for (i = 1; i < argc; i++) 
	{   if (argv[i][0] == '-') 
	    {   switch (argv[i][1]) 
		{
		case '-':	/* negate some default */
		    switch(argv[i][2]) 
		    {   case 'x':
			    noxflag++;
			    continue;
		    }
		    continue;

		case 'S':	/* create assembler (.s) file */
		    Sflag++;
		    cflag++;
		    continue;

  		case 's':	/* check for standard pascal  */
		    sflag++;
		    UNIMPLEMENTED(argv[i]);
		    continue;

		case 'o':	/* name the final output file */
		    if (++i < argc) 
		    {   outfile = argv[i];
			suf = getsuf(outfile);
			if ( EQ(suf,"c")  || EQ(suf,"b") || EQ(suf,asSuffix) )
			{	fprintf(stderr,"-o would overwrite %s\n", 
					       outfile);
				exit(8);
			}
		    }
		    continue;

		case 'R':	/* preserve relocation in b.out */
		    Rflag++;
		    continue;

		case 'U':	/* save ucode in filename.u */
		    Uflag++;
		    continue;

		case 'W':	/* ucode-to-ucode optimizer */
		    Wflag++;
		    continue;

		case 'O':	/* invoke object-code improver[?] */
		    Oflag++;
		    UNIMPLEMENTED(argv[i]);
		    continue;

		case 'g':	/* provide debugging hooks[?] */
		    gflag++;
		    UNIMPLEMENTED(argv[i]);
		    continue;

		case 'w':	/* suppress warning messages */
		    wflag++;
		    UNIMPLEMENTED(argv[i]);
		    continue;

		case 'v':	/* set version of runtime support */
		    version = argv[i];
		    continue;

		case 'E':	/* run preprocessor only */
		    exflag++;
		    UNIMPLEMENTED(argv[i]);
		    continue;

		case 'e':	/* set entrypoint for execution */
		    if (++i < argc)
			entrypoint = argv[i];
		    continue;

		case 'T':	/* where to begin loading program */
		    if (++i < argc) 
			textorigin = argv[i];
		    continue;

		case 'L':	/* print assembly list on file.slist */
		    Lflag++;
		    continue;

		case 'd':	/* dl format output */
		    dflag++;
		    continue;

		case 'r':	/* rev format output */
		    rflag++;
		    continue;

		case 'V':	/* set debugging option on */
		    debug++;
		    continue;

		case 'c':	/* compile-only, omit linkage */
		    cflag++;
		    continue;

		case 'P':	/* save temporary files */
		    Pflag++;
		    continue;

		case 'p':	/* save pascal listing even if no errors */
		    pflag++;
		    continue;

		default:
		    loadflags[flag_count++] = argv[i];
		    continue;

		}
	    }
	    /*  not a flag, put on appropriate action list */
		t = argv[i];
		/*  .p, compile it; exflag => preprocess, ignore suffix */
		    suf = getsuf(t);
		    if (EQ(suf, "p") || exflag || EQ(suf,"u") || EQ(suf,"U")
		     || EQ(suf, "pas") || EQ(suf, "uco") )
		    {   compile[compile_count++] = t;
			suf = asSuffix;
			t = setsuf(t, suf);
			if ( !Sflag && !Uflag )
			    delete[delete_count++] = t;
		    }


		/*  .a68 or .s, assemble it */
		    if (EQ(suf, "a68")  || EQ(suf, "s") )
		    {   assemble[assemble_count++] = t;
			t = setsuf(t, "b");
		    }

		/*  add files to load list -- generate suffix later */
		    load[load_count++] = t;

	}
        /*  set up appropriate start-up routine */
	    if (version && version[2]=='m') 
                crt0 = "/usr/sun/lib/crt0.b";

	/*  make sure .a68, .s, or .b files are present only when needed */
	    if ( Sflag 
	       && ((assemble_count > compile_count) 
		    || (load_count > compile_count)) )
		fprintf(stderr, 
	    "pc68 warning: -S incompatible with '.s', '.a68', and '.b'\n");

        /*  check for option conflicts */
            if ((eflag||Sflag||cflag) && (dflag || rflag)) 
            {   fprintf(stderr,"cc68: warning: -E,-S,-c disable -d,-r\n");
		dflag = 0;
		rflag = 0;
	    }

	/*  check for optimization/debugger conflicts */
	    if ( gflag && Oflag )
	    {	fprintf(stderr, "pc68: warning: -g disables -O\n");
		Oflag = 0;
	    }


    /*  run pascal compiler phases on each .p in succession */
/*	memdef    = mymktemp("/tmp/pc68mXXXXXX");*/
	utemp	  = mymktemp("/tmp/pc68XXXXXX.u");
	Utemp	  = mymktemp("/tmp/pc68XXXXXX.U");
	itemp	  = mymktemp("/tmp/pc68XXXXXX.b");
	for ( i=0; i < compile_count; i++ )
	{   t = compile[i];
	    if (EQ(getsuf(t),"p") || EQ(getsuf(t),"pas"))
	    {   /* pass 1 of compiler */
		argcount = 0;
		argvalue[argcount++] = "upas";
		argvalue[argcount++] = t;
		if (Uflag)
		    ucodefile = setsuf( t, "u" );
		else
		    ucodefile = utemp;
		argvalue[argcount++] = ucodefile;
/*		argvalue[argcount++] = list = setsuf(t,"err");*/
		argvalue[argcount] = 0;
		pc1errs = dosys( pc1, argvalue, 0, 0 );
	    }
	    else
	    {	pc1errs = 0;
		ucodefile = t;
                list = 0;
	    }
            if ( (pc1errs == 0) && Wflag ) /* ucode to ucode optimization */
            {   argcount = 0;
                argvalue[argcount++] = "lopt";
		argvalue[argcount++] = optlist = setsuf(t,"opt");
                argvalue[argcount]   = 0;
                if ( Uflag )
                    opt = setsuf(compile[i], "U");
                else
                    opt = delete[delete_count++] = Utemp;
                pc2errs = dosys( pc2, argvalue, ucodefile, opt );
                if (!pflag && (pc2errs == 0))
                    delete[delete_count++] = optlist;
            }
            else
                pc2errs = 0;

	    if ( pc1errs == 0 )
            {	if (!pflag && list)
		    delete[delete_count++] = list;
		if ( !Uflag )/*  pass 3 - ucode to assembler */
                {   argcount = 0;
                    argvalue[argcount++] = "ugen";
		    argvalue[argcount++] = (Wflag ? opt : ucodefile);
		    /* Changed suffix from a68 to s -PB May 18/82 */
		    argvalue[argcount++] = t = setsuf(compile[i], asSuffix);
/*                    argvalue[argcount++] = memdef;*/
                    argvalue[argcount] = 0;
                    dosys( pc3, argvalue, 0, "ugen68.log"); /*Temporary*/
        }   }   }
    /*  mark intermediate files for deletion */
	if (compile_count) {
/*	    delete[delete_count++] = memdef;*/
	    delete[delete_count++] = utemp;
            delete[delete_count++] = "symtbl";
	}

    /*  run assembler on each .a68 or .s file */
	if ( Sflag || errs || Uflag )
	    done();
	for ( i=0; i < assemble_count; i++ )
	{   argcount = 0;
	    argvalue[argcount++] = "as"; 
	    argvalue[argcount++] = "-g";	
	    if ( Lflag )
	    {   argvalue[argcount++] = "-L";
		argvalue[argcount++] = setsuf(assemble[i], "ls");
	    }
/*	    if ( EQ(getsuf(assemble[i]), "s")
	      || EQ(getsuf(assemble[i]), "a68")  )
		argvalue[argcount++] = trimsuf(assemble[i]);
	    else
 */
	    {
		argvalue[argcount++] = "-o";
		argvalue[argcount++] = setsuf(assemble[i], "b");
		argvalue[argcount++] = assemble[i];
	    }
	    argvalue[argcount] = 0;
	    dosys( as, argvalue, 0, 0);
	}

    /*  remove any temporary files present */
	remove();

    /*  loader */
	if ( errs == 0 && cflag == 0 )
	{   argcount = 0;
	    argvalue[argcount++] = "ld68";
	    /*  add -X and -x default unless --x given */
		argvalue[argcount++] = "-X";
		if (!noxflag)
		    argvalue[argcount++] = "-x";

	    /*  save relocation information */
		if (Rflag)
		    argvalue[argcount++] = "-r";
	    if (version)
		argvalue[argcount++] = version;

	    /*  set up specific entrypoint */
		if (entrypoint)
		{   argvalue[argcount++] = "-e";
		    argvalue[argcount++] = entrypoint;
		}

	    /*  set up specific text origin */
	        if (textorigin)
		{   argvalue[argcount++] = "-T";
		    argvalue[argcount++] = textorigin;
		}

	    /*  set output file name */
		if (dflag || rflag)	/* dl or rev => temporary */
		{   argvalue[argcount++] = "-o";
		    argvalue[argcount++] = delete[delete_count++]
					 = infile = itemp; 
		}
		else if (outfile)
		{   argvalue[argcount++] = "-o";
		    argvalue[argcount++] = outfile;
		}

	    /*  copy load flags first */
		for ( i=0; i < flag_count; i++ )
		    argvalue[argcount++] = loadflags[i];

	    /*  generate .b files */
		for ( i=0; i < load_count; i++ )
		    argvalue[argcount++] = load[i];

	    /*  library for debugging */
		if (gflag)
		    argvalue[argcount++] = "-lg";
	    
	    /*  start-up program */
		argvalue[argcount++] = crt0;

	    /*  use libpc68.a and libc.a in that order */
            	argvalue[argcount++] = "-lpc68";
		argvalue[argcount++] = "-lxc";
		argvalue[argcount++] = "-lleaf";
		argvalue[argcount++] = "-lpup";
		argvalue[argcount++] = "-lc";

	    argvalue[argcount] = 0;

	    dosys( ld, argvalue, 0, 0);

	    /*  remove single .b file */
		if (((compile_count+assemble_count)==1)
                    && (load_count==1) && (errs==0))
		    delete[delete_count++] = load[0];
	}

    /*  downloader */
	if ( errs==0 && cflag==0 && dflag!=0 )
	{   argcount = 0;
	    argvalue[argcount++] = "dl";
	    argvalue[argcount++] = infile;
	    if (version)
		argvalue[argcount++] = version;
	    /*  set up specific text origin */
	        if (textorigin)
		{   argvalue[argcount++] = "-T";
		    argvalue[argcount++] = textorigin;
		}
	    /*  decide what the output should look like */
		argvalue[argcount++] = "-o";
		if (!outfile)
		    if (load_count)
			outfile = setsuf(load[0],"dl");
		    else
			outfile = "d.out";
		argvalue[argcount++] = outfile;
		argvalue[argcount] = 0;
		dosys(dl, argvalue, 0, 0);
	}

    /* reverse */
	if (rflag && errs==0)
	{   argcount = 0;
	    argvalue[argcount++] = "rev";
	    argvalue[argcount++] = infile;
	    if ( outfile || (dflag!=0) )
		if (load_count)
		    outfile = setsuf(load[0],"r");
		else
		    outfile = "r.out";

	    argvalue[argcount++] = outfile;
	    argvalue[argcount] = 0;
	
	    dosys(rev, argvalue, 0, 0);
	}

	done();
	
}

dosys(cmd, argv, in, out)
    char *cmd, **argv, *in, *out;
{
    union wait status;
    int pid;

    if (debug) {
    	int i;
    	printf("%s:", cmd);
    	for (i = 0; argv[i]; i++)
    		printf(" %s", argv[i]);
    	if (in)
    		printf(" <%s", in);
    	if (out)
    		printf(" >%s", out);
    	printf("\n");
    }
    pid = vfork();
    if (pid < 0) {
    	fprintf(stderr, "pc: No more processes\n");
    	done();
    }
    if (pid == 0) {
    	if (in) {
    		close(0);
    		if (open(in, 0) != 0) {
    			perror(in);
    			exit(1);
    		}
    	}
    	if (out) {
    		close(1);
    		unlink(out);
    		if (creat(out, 0666) != 1) {
    			perror(out);
    			exit(1);
    		}
    	}
    	signal(SIGINT, SIG_DFL);
    	execv(cmd, argv);
    	perror(cmd);
    	exit(1);
    }
    while (wait(&status) != pid)
    	;
    if (WIFSIGNALED(status)) {
    	if (status.w_termsig != SIGINT)
    		fprintf(stderr, "Fatal error in %s\n", cmd);
    	errs = 100;
    	done();
    	/*NOTREACHED*/
    }
    if (status.w_retcode) {
    	errs = 1;
    }
    return (status.w_retcode);
}

done()
{
    remove();
    exit(errs);
}
onintr()
{

    errs = 1;
    remove();
    done();
}


char *
setsuf(cp, suf)
    char *cp;
    char *suf;
{
    register char *s, *s1;
    char buf[BUFSIZ];

    strcpy(buf, cp);
    s = getsuf(buf);
    strcpy(s, suf);
    s = s1 = savestr(buf);

    while (*s)
    	if (*s++ == '/')
    		s1 = s;
    return (s1);
}

#define    NSAVETAB	512
char    *savetab;
int    saveleft;

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
    return (cp);
}

remove()
{
    if (!Pflag )
	while ( --delete_count >= 0 )
	{	if (delete[delete_count])
		{   unlink(delete[delete_count]);
		    if (debug)
			fprintf(stderr, "Delete %s\n", delete[delete_count]);
		}
	}
    delete_count = 0;
}

char *
getsuf(cp)
    register char *cp;
{
    register char *lastc;
    register char *firstc;

    for (lastc=firstc=cp; *lastc; lastc++)
	;

    cp = lastc;
    while ( --cp > firstc )
    {   if ( *cp == '.' )
	    return(++cp);
    }
    return(lastc);
}

char *
trimsuf(cp)
    register char *cp;
{
    register char *s;
    char buf[BUFSIZ];

    strcpy(buf, cp);
    s = getsuf(buf);
    if (s[-1] == '.')
	s[-1] = 0;
    return(savestr(buf));
}

char *
addsuf(cp,suf)
    register char *cp;
    register char *suf;
{
    char buf[BUFSIZ];

    strcpy(buf, cp);
    strcat(buf, ".");
    strcat(buf, suf);
    return(savestr(buf));
}

/* Based on /usr/src/libc/gen/mktemp.c: generate temp file name */
/* Generalized so as to handle file type suffixes */
char *
mymktemp(as)
char *as;
{
	register char *s;
	register unsigned pid;
	register i;

	pid = getpid();
	/* here is the change from mktemp.c: */
	for (s = as; *s && *s!='.'; s++) ;
	while (*--s == 'X') {
		*s = (pid%10) + '0';
		pid /= 10;
	}
	s++;
	i = 'a';
	while (access(as, 0) != -1) {
		if (i=='z')
			return("/");
		*s = i++;
	}
	return(as);
}

/* file ld.c

		loader ld
		version 7/1/82
		revisions :

	7/07/82 MFM - Added support for the .align assembler pseudo-op.
		(See the Changes file on the as directory). Some additions
		were necessary to <a.out.h> and the symbol table table
		data structures.
	7/03/82 MFM - Added facilities to handle ranlib type archives.

		conditional compilation constants:
		mc68000 : iff true, mode of resulting output file is
			    made executable.
		debug : iff true, extra debugging information is printed
			    out.
		vax : make sure this is always undefined. It surrounds 
			    (probably) useless vaxish code.





*/
/* THINGSTODO HERE: 
	9. RESOLVE WHETHER OR NOT TO CHECK MACHINE STAMP ON ARCHIVE HDRS.
	12.GETFILE RETURNS THE FILE PTR TO THE BEGINNING OF THE FILE ALL
	   THE TIME, THEN RETURNS. THE CALLING ROUTINES THEN SKIP OVER
	   THE MAGIC NUMBER (SAME SIZE EVERY TIME) BEFORE CONTINUING.
	   IS THIS A WASTE OF TIME?
*/

#include <stdio.h>
#include <ar.h>
#include <a.out.h>
#include <sys/types.h>
#include <ranlib.h>
#include <sys/stat.h>

/*
 *  link editor
 */

#define	NSYM	2011
#define	NSYMPR	2011
#define ENDTAB 	0	/* marker for the end of unittab */
#define SKIPDEBUG 1	/* this unit is not debuggable */
#define NODEBUG 1 	/* tells enter r. not to worry about dst entries */
#define DEBUG   2	/* unit has no existing dstd entry */
#define PREDEBUG 3	/* this unit has dstd entries from prior loader run */
#define NDUNITS 260	/* # separate compilation units debuggable at once */
#define NUNITS  300	/* total # compilation units (debuggable or not) */
#define LOBYTE  0377	/* bit map to obtain low byte of a word */
#define FIVEBITS 037	/* bit map to obtain low 5 bits of a char */
#define FOURBITS 017	/* bit map to obtain low 4 bits of a char */

#ifndef SEGSIZE
#define SEGSIZE		0x80000
#endif

typedef struct symbol *symp;
struct symbol
{
	struct nlist_ 	s;		/* type and value */
	char 		*sname;		/* pointer to ascii name */
	symp 		*shash;		/* hash table index */
	unsigned 	sindex;		/* id of symbol in symtab */
	long 		stincr;		/* total value increment due to previous .align's */
	short		sincr;		/* whitespace size due to this .align */
};

typedef struct arg_link *arg;
struct arg_link
{
	char *arg_name;			/* the actual argument string */
	arg arg_next;			/* next one in linked list */
};

typedef struct arc_entry *arce;
struct arc_entry
{
	long	arc_offs;		/* offset in the file of this entry */
	arce	arc_e_next;		/* next entry, NULL if none */
};

typedef struct arc_link *arcp;
struct arc_link
{
	arce arc_e_list;		/* list of archive entries */
	arcp arc_next;			/* next archive */
};


typedef struct align_entry *aligne;
struct align_entry
{
	symp	symp;			/* ptr to hash table entry for aligner */
	aligne	nextale;		/* ptr to next element of the list */
	short 	modulo;			/* alignment modulo specifier */
};





/* global variables */

arg arglist;				/* linked list of arguments */
struct ar_hdr archdr;			/* directory part of archive */
arcp arclist = NULL;			/* list of archives */
arcp arclast = NULL;			/* last archive on arclist */
arce arcelast = NULL;			/* last entry in this entry list */
struct exec filhdr;			/* header file for current file */
struct symbol cursym;			/* current symbol */
char csymbuf[SYMLENGTH];		/* buffer for current symbol name */
struct symbol symtab[NSYM];		/* actual symbols */
char unittab[NUNITS];			/* table to identify debug units */
short unitno = 1;			/* counter thru unittab */
struct dstdentry dstab[NDUNITS];	/* symbolic debug units table */
symp lastsym;				/* last symbol entered */
int symindex;				/* next available symbol table entry */
symp hshtab[NSYM+2];			/* hash table for symbols */
symp local[NSYMPR];			/* symbols in current file */
int nloc;				/* number of local symbols per file */
int nund = 0;				/* number of undefined syms in pass 2*/
/* symp entrypt; */   			/* pointer to entry point symbol */
int argnum;				/* current argument number */
/* char ld[] = "~|^`s.ld.c  R1.11 on 11/18/80"; */
char *ofilename = OUT_NAME;		/* name of output file, default init */
char *filename;				/* name of current input file */
FILE *text;				/* file descriptor for input file */
FILE *rtext;				/* used to access relocation */
FILE *tout;				/* text portion */
FILE *dout;				/* data portion */
FILE *trout;				/* text relocation commands */
FILE *drout;				/* data relocation commands */
FILE *misout;				/* MIS portion */
FILE *dstout;				/* DST portion */


/* flags */
unsigned short	xflag;		/* discard local symbols */
unsigned short	Xflag;		/* discard locals starting with '?L' */
unsigned short	Sflag;		/* discard all except locals and globals*/
unsigned short	rflag;		/* preserve relocation bits, don't define common */
unsigned short	sflag;		/* discard all symbols */
unsigned short	dflag;		/* define common even with rflag */
unsigned short  Rflag;		/* -R seen in arguments - sets torigin */
unsigned short	mflag;		/* print rudimentary load map (berkeley = M) */
unsigned short	nflag;		/* create a 0410 file */
unsigned short	Nflag;		/* */
int	savernum;

/* used after pass 1 */
long torigin;		/* origin of text segment in final output */
long dorigin;		/* origin of data segment in final output */
long doffset;		/* current position in output data segment */
long borigin;		/* origin of bss segment in final output */
long corigin;		/* origin of common area */
long morigin;		/* origin of MIS area */
long lestorigin;	/* origin of lest */
long dstorigin;		/* origin of dst */

/* cumulative sizes set in pass 1 */
long	tsize;		/* size of text segment */
long	dsize;		/* size of data segment */
long	bsize;		/* size of bss segment */
long	csize;		/* size of common area */
long	rtsize;		/* size of text relocation area */
long	rdsize;		/* size of data relocation area */
long	ssize;		/* size of l.e. symbol area */
short	dstdno;		/* # entries in dstdir */
long	dssize;		/* size of symbolic symbol area */
long	missize;	/* size of modcal interface area - MIS */

/* variables needed to support ranlib */
int	rasciisize;	/* sizeof ranlib asciz table in bytes */
short	rantnum;	/* sizeof ranlib array (# of structures) */
struct	ranlib	*tab;	/* dynamically allocated ranlib array head */
char	*tabstr;	/* dynamically allocated string table for ranlib */
long	infilepos;	/* current position in input file (typically an archive) */

/* symbol relocation; both passes */
long	ctrel;
long	cdrel;
long	cbrel;

/* additional variables to support symbolic debugging */
long	abstorigin;	/* TEXTPOS on the output file */
long	absdorigin;	/* DATAPOS on the output file */
long	absborigin;	/* beginning of BSS segment on the output file */
long	absmorigin;	/* MODCALPOS on the output file */
long 	abslestorigin;	/* LESYMPOS on the output file */
long	absdstorigin;	/* DSTPOS on the output file */


/* variables to support dynamic alignment */
aligne	alptr = NULL;	/* ptr to top of aligne linked list (dynamically allocated) */







/* error messages */

char *e1 = "missing argument following command option -%c";
char *e2 = "unrecognized option: -%c";
char *e3 = "premature end of file %s";
char *e4 = "read error on file %s";
char *e5 = "unknown type of file %s";
char *e6 = "multiply defined symbol %s in file %s";
/* char *e7 = "entry point not in text"; */
char *e8 = "cannot create file %s";
char *e9 = "cannot reopen output file";
char *e10 = "file symbol overflow";
char *e11 = "internal error - undefined symbol %s in file %s";
char *e12 = "format error in file %s, bad relocation size";
char *e13 = "format error in file %s, relocation outside of segment";
char *e14 = "error writing file %s";
char *e15 = "file %s not found";
char *e16 = "hash table overflow";
char *e17 = "symbol table overflow";
/*char *e18 = "format error in file %s, null symbol name";*/
char *e19 = "format error in file %s, invalid symbol id in relocation command";
/*char *e20 = "format error in file %s, bad type of symbol %s in reloc command";*/
char *e21 = "format error in file %s, bad address in relocation command";
char *e22 = "format error in file %s, asciz symbol name %s";
char *e23 = "too many debug units. Overflow occurred in file %s";
char *e24 = "insufficient memory to load library %s directory";
char *e25 = "library %s directory contains trash";


/* functions */

long getsym();
symp lookup();
symp slookup();
symp *hash();
long relext();
long relcmd();
long atox();
char *asciz();





/* main -	The link editor works in two passes.  In pass 1, symbols
		are defined.  If alignment specifying symbols are present,
		an additional operation in the middle is performed to
		determine how much total white space is to be included in
		the output file. In pass 2, the actual text and data will
		be output along with any relocation commands and symbols.
*/

main(argc, argv)
int argc;
char **argv;
{
	register arg argp;	/* current argument */
	
	torigin = 0x2000;	/* reset with -R flag */
	procargs(argc, argv);
	
	/* pass 1 */
	for (argp = arglist; argp; argp = argp->arg_next)
		load1arg(filename = argp->arg_name);
	
	middle();
	
	/* pass 2 */
	setupout();
	for (argp = arglist; argp; argp = argp->arg_next)
		load2arg(filename = argp->arg_name);
	
	finishout();
	exit(0);
}






/* progargs -	Process command arguments
 */

procargs(argc, argv)
int argc;
char **argv;
{
	for (argnum = 1; argnum < argc; argnum++)	/* for each arg */
	{
		if (argv[argnum][0] == '-') procflags(argc, argv);
		else newarg(argv[argnum]);	/* build linked list */
	}
	if (Rflag) torigin = savernum;			/* MFM */
}


/* newarg -	Create a new member of linked list of arguments
 */
newarg(name)
register char *name;
{
	register arg a1, a2;
	a1 = (arg)calloc(1, sizeof(*a1));
	a1->arg_name = name;
	a1->arg_next = NULL;
	if (arglist == NULL) arglist = a1;
	else	/* link new one on end */
	{
		for (a2 = arglist; a2->arg_next; a2 = a2->arg_next);
		a2->arg_next = a1;
	}
}





/* procflags -	Process flag arguments.
 */

procflags(argc, argv)
int 	argc;
char 	**argv;
{
	char 	*flagp = &argv[argnum][1];
	char 	c;

	while(c = *flagp++) switch(c)
	{
	case 'o':
		if (++argnum >= argc) error(e1, c);
		else ofilename = argv[argnum];
		break;
	case 'u':
		if (++argnum >= argc) error(e1, c);
		else enter(slookup(argv[argnum]), NODEBUG);
		break;
	case 'e':
		if (++argnum >= argc) error(e1, c);
		/* else enter(slookup(argv[argnum]), NODEBUG);
		entrypt = lastsym; */
		error("-e is currently ignored");	/* cmb */
		break;
	case 'D':
		if (++argnum >= argc) error(e1, c);
		else dsize = atol(argv[argnum]);
		break;
	case 'R':	/* -R will override -r */
		Rflag++;				/* MFM */
		if (++argnum >= argc) error(e1, c);
		else savernum = atox(argv[argnum]);	/* MFM */
		break;
	case 'l': newarg(argv[argnum]); return;
	case 'm': mflag++; break;
	case 'x': xflag++; break;
	case 'X': Xflag++; break;
	case 'S': Sflag++; break;
	case 'r': rflag++; 
		  torigin = 0;				/* MFM */
		  break;
	case 's': sflag++; xflag++; break;
	case 'd': dflag++; break;
	case 'n': nflag++; break;
	case 'N': Nflag++; break;
	default:	error(e2, c);
	}
}

long atox(s)
register char *s;
{
	register long result = 0;
	for (; *s != 0; s++)
	  if (*s >= '0' && *s <= '9') result = (result<<4) + *s-'0'; else
	  if (*s >= 'a' && *s <= 'f') result = (result<<4) + *s-'a'+10; else
	  if (*s >= 'A' && *s <= 'F') result = (result<<4) + *s-'A'+10; else
	  error("atox: illegal hex argument (%c)",*s);
	return(result);
}





/* scan file to find defined symbols */
load1arg(cp)
register char 	*cp;
{
	register arcp 		ap;  	/* ptr to new archive list element */
	register struct ranlib *tp;	/* ptr to ranlib array element */
	int			kind;
	int			obs=0;	/* true iff obsolete directory on ar */
	struct stat		stb;

	kind = getfile(cp);		/* open file and read 1st word */
	if (mflag) printf("%s\n", filename);

	switch (kind)
	{
	case 1 /* FMAGIC */:
		load1(0L, 0);		/* pass1 on regular file */
		break;

	/* regular archive */
	case 2 /* ARCMAGIC */:
		ap = (arcp)calloc(1, sizeof(*ap));
		ap->arc_next = NULL;
		ap->arc_e_list = NULL;
		if (arclist)
		{
			arclast->arc_next = ap;
			arclast = ap;
		}
		else arclast = arclist = ap;
		fseek(text, SARMAG, 0);	/* skip magic word */
		fread(&archdr, sizeof(archdr), 1, text);
		if (!feof(text) &&
		   (strncmp(archdr.ar_name, DIRNAME, sizeof(archdr.ar_name))==0) &&
		   (obs = (stb.st_mtime <= archdr.ar_date))) {
			/*
			It is an up-to-date directory in the first file
			DIRNAME. Read the table of contents and its associated
			string table. Pass thru the library resolving symbols
			until nothing changes for an entire pass (i.e. you can
			get away with backward references when there is a table
			of contents!).
			*/
			dread(&rantnum, sizeof(rantnum), 1, text);
			tab = (struct ranlib *) malloc(
					rantnum*sizeof(struct ranlib));
			if ( !tab) fatal(e24, filename);
			dread(&rasciisize, sizeof(rasciisize), 1, text);
			tabstr = (char *)malloc(rasciisize);
			if (!tabstr) fatal(e24, filename);
			dread(tabstr, 1, rasciisize, text);
			dread(tab, sizeof(struct ranlib), rantnum, text);
			for (tp=(&tab[rantnum]); --tp >= tab; ) {
				if (tp->ran_un.ran_strx < 0 ||
				   tp->ran_un.ran_strx >= rasciisize)
					error(e25, filename);
				tp->ran_un.ran_name = tabstr
							+ tp->ran_un.ran_strx;
			}
			infilepos = ftell(text);
			while (ldrand())
				continue;
			
			/* now that we're finished with the directory, release
			   the space.
			*/
			free((char *)tab);		/* berkeley = cfree */
			free(tabstr);			/* berkeley = cfree */
			break;
			}

		fseek(text, SARMAG, 0);			/* move past magic word */
		if (obs) {
			printf("NOTE: DIRECTORY FOR LIBRARY %s IS OBSOLETE. \n",				filename);
			dread(&archdr, sizeof(archdr), 1, text);
			infilepos = SARMAG + sizeof(archdr) + 
					((archdr.ar_size + 1)&~1);
			fseek(text, infilepos, 0);
		}
		else {
			printf("NOTE: LIBRARY %s HAS NO DIRECTORY.\n",filename);
			infilepos = SARMAG;
		}
		while (fread(&archdr, sizeof archdr, 1, text) && !feof(text))
		{
			infilepos += sizeof(archdr);
			if (load1(infilepos, 1))		/* arc pass1 */
			{
				register arce ae = (arce)calloc(1, sizeof(*ae));
				
				ae->arc_e_next = NULL;
				ae->arc_offs = infilepos;
				if (arclast->arc_e_list)
				{
					arcelast->arc_e_next = ae;
					arcelast = ae;
				}
				else arclast->arc_e_list = arcelast = ae;
			}
			infilepos += (archdr.ar_size + 1)&~1;
			fseek(text, infilepos, 0);
		}
		break;

	default:
		fatal(e5, filename);
	}
	fclose(text);
	fclose(rtext);
}

		
		
		
	
/* step -	Advance to the next archive member, which is at offset infilepos
		in the archive. If the member is useful, record its location
		in the arclist structure for use in pass 2. Mark the end of the
		archive in arclist with a NULL.
*/

step()
{

	int	load1result;
	
	fseek(text, infilepos, 0);
	if (fread(&archdr, sizeof archdr, 1, text) && !feof(text))
		{
			infilepos += sizeof(archdr);
			if (load1result = load1(infilepos, 1))	/* arc pass1 */
			{
				arce ae = (arce)calloc(1, sizeof(*ae));
				ae->arc_e_next = NULL;
				ae->arc_offs = infilepos;
				if (arclast->arc_e_list)
				{
					arcelast->arc_e_next = ae;
					arcelast = ae;
				}
				else arclast->arc_e_list = arcelast = ae;
				if (mflag) printf("\t%s\n", archdr.ar_name);
			}
			infilepos += (archdr.ar_size + 1)&~1;
			fseek(text, infilepos, 0);
			return(load1result);
		}
#ifdef debug
printf("ERROR: step has overread the archive file.\n");
#endif
	return(0);
}





/* ldrand - 	One pass over an archive with a table of contents.
		Remember the number of symbols currently defined,
		then call step on members which look promising (i.e.
		that define a symbol which is currently externally
		undefined). Indicate to our caller whether this process
		netted any more symbols.
*/

ldrand()
{
	register symp sp;
	register struct ranlib *tp, *tplast;
	register long loc;
	int  nsymt = symindex;	/* berkeley = symx(nextsym) */

	tplast = &tab[rantnum - 1];
	for (tp = tab; tp <= tplast; tp++) {
		/* inline expansion of the pertinent parts of slookup */
		cursym.sname = tp->ran_un.ran_name;
		cursym.s.n_length = strlen(cursym.sname);	/* no trail 0 */
		cursym.s.n_type = EXTERN+UNDEF;
		if ((sp = *hash()) == NULL) 
			continue;
		/* replaces
			if ((sp = slookup(tp->ran_un.ran_name)) == NULL)
				continue;
		*/
		if (sp->s.n_type != EXTERN+UNDEF)
			continue;
		/* if we get here, the symbol is extern and defined */
		infilepos = tp->ran_off;
#ifdef debug
printf("In ldrand. About to call step with infilepos = %x\n",infilepos);
#endif
		step();
		loc = tp->ran_off;
		while (tp < tplast && (tp+1)->ran_off == loc)
			tp++;
	}
	return(symindex != nsymt);	/* i.e. return true iff symindex has
					   been updated by step() */
}




/* load1 -	Accumulate file sizes and symbols for single file
		or archive member.  Relocate each symbol as it is
		processed to its relative position in its csect.
		If libflg == 1, then file is an archive hence
		throw it away unless it defines some symbols.
		Here we also accumulate .comm symbol values.
*/

load1(sloc, libflg)
register long 	sloc;	/* location of first byte of this file */
int 		libflg;	/* 1 => loading a library, 0 else */
{
	register long endpos;	/* position after l.e. symbol table */
	register int savindex;	/* symbol table index on entry */
	register int ndef;	/* number of symbols defined */
	register short i;
	
	readhdr(sloc);
	filhdr.a_modcal = (filhdr.a_modcal+1) & ~1;	/* needed? MFM */
	
	fseek(text, DSTDPOS, 0);
	/* even if a unit has been previously run thru the loader, it must
	   be done again to ensure that unit numbers are unique and that
	   dstd entries are accurate. The order in which o-files are specified
	   in the param list is not known.
	*/
	if (filhdr.a_dstdir) { /* previously run thru the loader */
		for (i = 0; i < filhdr.a_dstdir;i++) 
			dread(&dstab[dstdno++], sizeof(struct dstdentry), 1, text);
		unittab[unitno] = PREDEBUG;
	}
	else if (filhdr.a_dsyms) {
		unittab[unitno] = DEBUG;
		dstdno++;
	}
	else unittab[unitno] = SKIPDEBUG;
	if (unitno >= NUNITS) fatal(e23, filename);
	if (dstdno > NDUNITS) fatal(e23, filename);

	ctrel = tsize;
	cdrel += dsize;
	cbrel += bsize;
	ndef = 0;
	nloc = 0;
	
	savindex = symindex;
	sloc += LESYMPOS;
	fseek(text,sloc, 0);	/* skip to symbols */
	endpos = sloc + filhdr.a_lesyms;
	while (sloc < endpos)
	{
		sloc += getsym();
		ndef += sym1();	/* process one symbol */
	}

	unitno++;
	if (libflg==0 || ndef) {
		tsize += filhdr.a_text;
		dsize += filhdr.a_data;
		bsize += filhdr.a_bss;
		ssize += nloc;			/* count local symbols */
		rtsize += filhdr.a_trsize;
		rdsize += filhdr.a_drsize;
		dssize += filhdr.a_dsyms;
		missize += filhdr.a_modcal;
		return(1);
	}
	/*
	 * No symbols defined by this library member.
	 * Rip out the hash table entries and reset the symbol table.
	 */
	while (symindex>savindex) *symtab[--symindex].shash = 0;
	return(0);
}





/* sym1 -	Process pass1 symbol definitions.  This involves flushing
		un-needed symbols, and entering the rest in the symbol table.
		Returns 1 if a symbol was defined and 0 else.
 */
sym1()
{
	register symp sp;
	register unsigned char ctype = cursym.s.n_type; /* type of the current symbol */
	register unsigned char ltype;
	register long cvalue;

	if (Sflag) switch(ctype & FOURBITS)
		/* i.e. disregard the EXTERN and ALIGN bits */
	{
	case TEXT:
	case BSS:
	case DATA:
		break;
	default:
		return(0);
	}
	if ((ctype&EXTERN) == 0)
	{
		if (xflag || (Xflag && (cursym.sname[0] == '?')
			&& (cursym.sname[1] == 'L')));
		else nloc += sizeof(cursym.s) + cursym.s.n_length;
		return(0);
	}
	symreloc(); 			/* relocate symbol in file */
	/* symreloc modifies cursym.s.n_type and cursym.s.n_value */
	
	if (enter(lookup(),(int)unittab[unitno])) return(0);
		/* install symbol in table */

	/* If we get here, then symbol was already present.
	   If symbol is already defined then return; multiple
	   definitions are caught later.   If current symbol is
	   not EXTERN e.g. it is local, let the new one override */

	ltype = (sp = lastsym)->s.n_type;
	ctype = cursym.s.n_type;
	if (ltype & EXTERN)
	{
		if ((ltype & FOURBITS) != UNDEF) return(0);
	}
	else if (!(ctype & EXTERN)) return(0);
	cvalue = cursym.s.n_value;
	if (ctype == EXTERN+UNDEF)
	{
		/* Check for .comm symbols. They will have a non-zero value. */
		if (cvalue>sp->s.n_value) sp->s.n_value = cvalue;
		return(0);
	}
	if (sp->s.n_value!=0 && ctype == EXTERN+TEXT) return(0);
	sp->s.n_type = ctype;	/* define something new */
	sp->s.n_value = cvalue;
	return(1);
}





/* middle -	Finalize the symbol table by adding the origins of
		each csect to symbols.  Also define the end stuff,
		adjusting the boundaries of the csect depending on
		options.
 */

middle()
{
	register symp sp;

	enter(slookup("etext"), NODEBUG);
	enter(slookup("edata"), NODEBUG);
	enter(slookup("end"), NODEBUG);
	enter(slookup("_etext"), NODEBUG);
	enter(slookup("_edata"), NODEBUG);
	enter(slookup("_end"), NODEBUG);
	/*
	 * Assign common locations.
	 */
	csize = 0;
	if (dflag || rflag==0)
	{
		ldrsym(slookup("_etext"), tsize, EXTERN+TEXT);	/* set value */
		ldrsym(slookup("_edata"), dsize, EXTERN+DATA);
		ldrsym(slookup("_end"), bsize, EXTERN+BSS);
		ldrsym(slookup("etext"), tsize, EXTERN+TEXT);	/* set value */
		ldrsym(slookup("edata"), dsize, EXTERN+DATA);
		ldrsym(slookup("end"), bsize, EXTERN+BSS);
		common();
	}
	nund = 0;				/* no undefined initially */
/*	ssize = size of local symbols to be entered in load2		*/
	doffset = 0;				/* beginning of data seg */

	/* Alignment symbols will not be activated if rflag <> 0. If, however,
	   pass 1 has seen any alignment symbols, do the following:
        */
	if (alptr) {
		findal1(TEXT);
		findal1(DATA);
		findal1(BSS);
	}

	/*
	 * Now set symbols to their final value
	 */
	adjust_sizes(1);

	for (sp = symtab; sp < &symtab[symindex]; sp++)  sym2(sp);
	bsize += csize;
	morigin = borigin + bsize;		/* MIS after bss area */
	/* unittab[unitno] is 0 because array was initialized that way */
	unitno = 1;				/* reset it for pass 2 trek */
	lestorigin = morigin + missize;
	dstorigin = lestorigin + ssize + dstdno*sizeof(struct dstdentry);
	if (dstdno) {
		/* there's at least 1 dstdentry to be made */
		/* save these locations for sure */
		abstorigin = torigin;
		absdorigin = dorigin;
		absborigin = borigin;
		absmorigin = morigin;
		abslestorigin = lestorigin;
		absdstorigin = dstorigin;
	}
}




/* common -	Set up the common area.  */

common()
{
	register symp sp;
	register long val;

	csize = 0;
	for (sp = symtab; sp < &symtab[symindex]; sp++)
		if (sp->s.n_type == EXTERN+UNDEF && ((val = sp->s.n_value) != 0))
		{
			val = (val + 1) & ~01;	/* word boundary */
			sp->s.n_value = csize;
			sp->s.n_type = EXTERN+COMM;
			csize += val;
		}
}





/* sym2 -	Assign external symbols their final value and compute ssize */
sym2(sp)
register symp sp;
{
	ssize += sizeof(sp->s) + sp->s.n_length;
	switch (sp->s.n_type)
	{
	case EXTERN+UNDEF:
		if ((rflag == 0 || dflag) && sp->s.n_value == 0)
		{
			if (nund++==0)
				printf("ld: Undefined external - \n");
			printf("\t%s\n", asciz(sp->sname,sp->s.n_length));
		}
		break;

	case EXTERN+ABS:
	default:
		break;

	case EXTERN+TEXT:
	case EXTERN+TEXT+ALIGN:
		sp->s.n_value += torigin + sp -> stincr;
		break;

	case EXTERN+DATA:
	case EXTERN+DATA+ALIGN:
		sp->s.n_value += dorigin + sp -> stincr;
		break;

	case EXTERN+BSS:
	case EXTERN+BSS+ALIGN:
		sp->s.n_value += borigin + sp -> stincr;
		break;

	case EXTERN+COMM:
		sp->s.n_type = EXTERN+BSS;
		sp->s.n_value += corigin + sp -> stincr;
		break;
	}
}





/* ldrsym -	Force the definition of a symbol */
ldrsym(asp, val, type)
register symp 	asp;
long 		val;			/* value of the symbol */
char 		type;			/* its type */
{

	if (asp== 0) return;
	if (asp->s.n_type != EXTERN+UNDEF || asp->s.n_value)
	{
		error(e6, asciz(asp->sname, asp->s.n_length), filename);
		return;
	}
	asp->s.n_type = type;
	asp->s.n_value = val;
	asp->s.n_unit = 0;
}






/* findal1 -	Called as a separate mini-pass only if alignment symbols
		have been seen in pass 1. Once one of these occurs, all
		succeeding symbols in the current section of the output
		file will have to be adjusted downward. Since more than
		one alignment symbol may be encountered during pass 1, the
		effect is cumulative. This routine must juggle the alptr
		linked list of such alignment symbols and the total linked
		list of arguments to include pertinent library members.
		The easiest method of handling multiple alignment
		symbols is to perform a separate mini-pass thru the
		symbol table for each one.

		If files have been previously loaded (using the -r flag),
		excessive white space may be put into the object
		file. Two solutions are possible: a)  Do nothing for 
		alignment symbols whenever -r is specified. i.e. delay
		any action on them until the final load; or b) Have an
		algorithm that first collapses previously built white space
		before doing any construction of white space. I think the
		first option is more reasonable and it is the one that is
		implemented here.
*/

findal1(aligntype)
register unsigned char aligntype;	/* ids the sgmnt the aligner is in */
{
	register symp sp;
	register long alignspot;	/* offset in seg for start of white space */
	register long	incr;		/* size of white space */
	register aligne alp = alptr;

	do {
		/* Symbol adjustments must go in 2 phases. First, it is
		   necessary to determine the size and location of the white
		   space. Then each symbol found to be succeeding the location
		   of the white space must be incremented by this amount.
		*/
		
		if (aligntype == (alp->symp->s.n_type & FOURBITS)) {
			adjust_sizes(0);
			alignspot = alp->symp->s.n_value + alp->symp->stincr;
			switch (aligntype) {
		case TEXT:
			for (incr=torigin+alignspot;incr++ % alp->modulo;) ;
			incr -= torigin + alignspot + 1;
			tsize += incr;
			break;
		case DATA:
			for (incr=dorigin+alignspot; incr++ % alp->modulo;) ;
			incr -= dorigin + alignspot + 1;
			dsize += incr;
			break;
		case BSS:	/* is this possible? */
			for (incr= borigin+alignspot; incr++ % alp->modulo;) ;
			incr -= borigin + alignspot + 1;
			bsize += incr;
			break;
		}
		
		alp->symp->sincr = incr;	/* record for later use in load2td */
		for (sp = symtab; sp < &symtab[symindex]; sp++) 
			if ((aligntype == (sp->s.n_type & FOURBITS)) &&
			    (sp != alp->symp))	/* not the symbol causing the fuss */
					sp->stincr += incr;
		}
		alp = alp -> nextale;
	} while (alp != NULL);
}





adjust_sizes(final)
int	final;	/* <>0 only the last time this is called to ensure proper
		   alignments of segments and sizes */
{
	if (final) {
		tsize = (tsize + 1) & ~01;
		dsize = (dsize + 1) & ~01;
	}
	if (nflag)
		dorigin = torigin+(tsize+(PAGESIZE-1))& ~(PAGESIZE-1);
	else if (Nflag)
		dorigin = torigin + (tsize+(SEGSIZE-1))& ~(SEGSIZE-1);
	else dorigin = torigin + tsize;
	corigin = dorigin + dsize;
	borigin = corigin + csize;
}





/* setupout -	Set up for output.  Create output file and a temporary
		files for the data area and relocation commands if
		necessary.  Write the header on the output file.
 */

setupout()
{
	register struct exec *f = &filhdr;
	
	if (nflag) f -> a_magic = NMAGIC;
	else f -> a_magic = FMAGIC;
	f->a_text = tsize;
	f->a_data = dsize;
	f->a_bss = bsize;
	f->a_trsize = rflag? rtsize: 0;
	f->a_drsize = rflag? rdsize: 0;
	f->a_lesyms = sflag? 0:ssize;
	f->a_dstdir = dstdno;
	f->a_modcal = missize;
	f->a_dsyms = dssize;
	dstdno = 0;
	/* if (entrypt)
	{
		if (entrypt->s.n_type!=EXTERN+TEXT) error(e7);
		else f->a_entry = entrypt->s.n_value;
	}
	else f->a_entry = 0; */
	f->a_entry = torigin;		/* cmb */
	if ((tout = fopen(ofilename, "w")) == NULL) fatal(e8, ofilename);
	if ((dout = fopen(ofilename, "a")) == NULL) fatal(e9, ofilename);
	fseek(dout, (long)(DATAPOS), 0);
	if (missize) 
		if ((misout = fopen(ofilename, "a")) == NULL)
			fatal(e9,ofilename);
	if (dssize) {
		if ((dstout = fopen(ofilename, "a")) == NULL)
			fatal(e9,ofilename);
		fseek(dstout, (long)(DSTPOS), 0);
		}
	if (rflag)
	{
		if ((trout = fopen(ofilename, "a")) == NULL) fatal(e9, ofilename);
		fseek(trout, (long)RTEXTPOS, 0); /* start of text relocation */
		if ((drout = fopen(ofilename, "a")) == NULL) fatal(e9,ofilename);
		fseek(drout, (long)RDATAPOS, 0);	/* to data reloc */
	}
	fwrite(f, sizeof(filhdr), 1, tout);
}





/* load2arg -	Load a named file or an archive */

load2arg(cp)
char 	*cp;
{
	register arce entry;		/* pointer to current entry */
	
	switch (getfile(cp))
	{
	case 1 /* FMAGIC */:		/* normal file */
		
		dread(&filhdr, sizeof filhdr, 1, text);
		load2(0L);
		break;
	case 2 /* ARCMAGIC */:		/* archive */
		for(entry=arclist->arc_e_list; entry; entry=entry->arc_e_next)
		{
			fseek(text, infilepos = entry->arc_offs, 0);
			dread(&filhdr, sizeof filhdr, 1, text);
			load2(infilepos);		/* load the file */
		}
		arclist = arclist->arc_next;
		break;
	default:	bletch("bad file type on second pass");
	}
	fclose(text);
	fclose(rtext);
}






/* load2 -	Actually output the text, performing relocation as necessary.
 */
load2(sloc)
register long sloc;	/* position of filhdr in current input file */
{
	register symp sp;
	register long loc=sloc;	/* current position in file */
	register long endpos;	/* end of symbol segment */
	register int symno = 0;
	register unsigned short type;

	readhdr(sloc);
	ctrel = torigin;
	cdrel += dorigin;
	cbrel += borigin;

	/*
	 * Reread the symbol table, recording the numbering
	 * of symbols for fixing external references.
	 */
	loc += LESYMPOS;
	fseek(text, loc, 0);
	endpos = loc + filhdr.a_lesyms;
	while(loc < endpos)
	{
		loc += getsym();
		if (++symno >= NSYMPR) fatal(e10);
		symreloc();
		/* NOTE : Berkeley's loader expands symreloc inline here */
		type = cursym.s.n_type;
		if (Sflag)
		{
			switch(type&FOURBITS)
			{
			case TEXT:
			case BSS:
			case DATA:
				break;
			default:
				continue;		
			}
		}
		if ((type&EXTERN) == 0)		/* enter local symbols now */
		{
			if (xflag || (Xflag && (cursym.sname[0] == '?')
				&& (cursym.sname[1] == 'L')));
			else enter(lookup(), filhdr.a_dsyms);
			continue;
		}
		if ((sp = lookup()) == NULL) fatal(e11,
			asciz(cursym.sname, cursym.s.n_length),filename);
		local[symno - 1] = sp;
		if (cursym.s.n_type != EXTERN+UNDEF
		 && (cursym.s.n_type != sp->s.n_type
		  || cursym.s.n_value != sp->s.n_value - sp->stincr))
			error(e6, asciz(cursym.sname, cursym.s.n_length),
				filename);
	}

	switch (unittab[unitno++]) {
		case PREDEBUG :
			/* using symno here only as a convenient counter */
			for (symno=0; symno < filhdr.a_dstdir; symno++) 
				filldstd(&dstab[dstdno++]);
			break;
		case DEBUG :
			filldstd(&dstab[dstdno++]);
		case SKIPDEBUG :
			break;
		default :
			bletch("overran unittab in load2 with file %s",
				filename);
		}

	/* position file ptrs conveniently */
	fseek(text, sloc+TEXTPOS, 0);
	fseek(rtext, sloc+RTEXTPOS, 0);
	/* now output the final text segment */
	load2td(tout, trout, torigin, filhdr.a_text, filhdr.a_trsize);
	
	fseek(text, sloc+DATAPOS, 0);
	fseek(rtext, sloc+RDATAPOS, 0);
	/* now output the final data segment */
	load2td(dout, drout, doffset, filhdr.a_data, filhdr.a_drsize);
	
	torigin += filhdr.a_text;
	dorigin += filhdr.a_data;
	doffset += filhdr.a_data;
	borigin += filhdr.a_bss;
	
	if (missize) {
		fseek(text, sloc+MODCALPOS, 0);
		fseek(misout, morigin, 0);
		dcopy(text, misout, filhdr.a_modcal);
		morigin += filhdr.a_modcal;
		}
	if (dssize) {
		fseek(text, sloc+DSTPOS, 0);
		fseek(dstout, dstorigin, 0);
		dcopy(text, dstout, filhdr.a_dsyms);
		dstorigin += filhdr.a_dsyms;
		}
}





filldstd(d)
register struct dstdentry *d;
{
	d -> d_tstart += torigin - abstorigin;
	d -> d_dstart += dorigin - absdorigin;
	d -> d_bstart += corigin - absborigin;
	d -> d_mstart += morigin - absmorigin;	/* ??? */
	d -> d_lesstart += lestorigin - abslestorigin;
	d -> d_dststart += dstorigin - absdstorigin;
	return;
}



#ifndef debug
unsigned char wspace = 0;
#else
unsigned char wspace = 255;
#endif


/* load2td - load the text or data section of a file performing relocation */

load2td(outf, outrf, txtstart, txtsize, rsize)
FILE *outf;				/* text or data portion of output file */
FILE *outrf;				/* text or data relocation part of output file */
long txtstart;				/* initial offset of text or data segment */
long txtsize;				/* number of bytes in segment */
register long rsize;			/* size of appropriate relocation data */
{
	struct r_info rel;		/* the current relocation command */
	register struct r_info *relptr = &rel;	/* shortcut ptr to rel */
	register int size;		/* number of bytes to relocate */
	register long offs;		/* value of offset to use */
	register long pos = 0;		/* current input position */
	register short	incr;		/* sizeof whitespace added by .align */

	rsize /= sizeof(rel);		/* change it into a count of commands */
	while(rsize--)			/* for each relocation command */
	{
		if (pos >= txtsize) bletch("relocation after end of segment");
		dread(relptr, sizeof rel, 1, rtext);
		offs = local[relptr->r_symbolnum]->stincr;
		switch(relptr->r_segment)
		{
		case REXT:
			offs += relext(relptr);
			break;
		case RTEXT:
			offs += torigin;
			break;
		case RDATA:
			offs += dorigin - filhdr.a_text;
			break;
		case RBSS:
			offs += borigin - (filhdr.a_text + filhdr.a_data);
			break;
		}
#ifdef vax
		if (relptr->rdisp)
			offs -= relptr->r_address + txtstart; 
			fprintf(stderr, "BINGO! REPORT THIS MESSAGE TO MIKE\n");
#endif
		switch(relptr->r_length)
		{
		case RBYTE:
			size = 1; break;
		case RWORD:
			size = 2; break;
		case RLONG:
			size = 4; break;
		case RALIGN:
			if (relptr->r_address > txtsize) fatal(e13, filename);
			if (relptr->r_address < pos) error(e21, filename);
			else if (!rflag) {
				dcopy(text, outf, relptr->r_address - pos);
				/* now slip in a little white space for momma */
				incr = local[relptr->r_symbolnum]->sincr;
				while (incr-- > 0) putc(wspace, outf);
				pos = relptr->r_address;
			}
			goto rflagchk;
		default:
			fatal(e12, filename);
		}

		if (relptr->r_address > txtsize) fatal(e13, filename);
		else pos = relcmd(pos, relptr->r_address, size, offs, outf);
rflagchk:	if (rflag)	/* write out relocation commands */
		{
			relptr->r_address +=  txtstart;
			relptr->r_symbolnum = (relptr->r_segment == REXT)?
				local[relptr->r_symbolnum]->sindex: 0;
			fwrite(relptr, sizeof rel, 1, outrf);
		}
	}
	dcopy(text, outf, txtsize - pos);
}





/* relext -	Find the offset of an REXT command and fix up the rel cmd.
 */

long relext(r)
register struct r_info *r;
{
	register symp sp;		/* pointer to symbol for EXT's */
	register long offs;			/* return value */

	if ((r->r_symbolnum < 0 || r->r_symbolnum >= NSYMPR) ||
		((sp = local[r->r_symbolnum]) == NULL))
	{
		error(e19, filename);
		offs = 0;
	}
	else
	{
		offs = sp->s.n_value;
		switch(sp->s.n_type & FOURBITS)
		{
		case TEXT: r->r_segment = RTEXT; break;
		case DATA: r->r_segment = RDATA; break;
		case BSS: r->r_segment = RBSS; break;
		case UNDEF:
			if (rflag && (sp->s.n_type & EXTERN))
			{
				r->r_segment = REXT;
				break;
			}		
/*		default: error(e20, filename, asciz(sp->sname));	*/
		}
	}
	return(offs);
}


/* relcmd -	Seek to <position> in file by copying from text to
		outf, then Add an offset to the next <size>
		bytes in the text and write out to outf.
 */

long relcmd(current, position, size, offs, outf)
long current;		/* current position in file */
long position;		/* where in file to perform relocation */
int size;		/* number of bytes to fix up */
long offs;		/* the number to fix up bye */
FILE *outf;		/* where to write to */
{
	/* Note : Since relcmd simply copies from the input file to the output
	   file (regardless of what has been placed on the output file
	   previously), aligners that have added whitespace to the output file
	   do not affect relocation commands; the processing of aligners
	   has no effect on the input file so the relationship between the
	   relocation command and the text/data segment in the input file
	   remains valid at all times. The only effect of aligners is on the
	   offs.
	*/

	register int i, c;
	register int buf = 0;
	if (position < current)
	{
		error(e21, filename);
		return(current);
	}
	dcopy(text, outf, position - current);
	for (i = 0; i < size; i++)
	{
		if ((c = getc(text)) == EOF) fatal(e3, filename);
		buf = (buf << 8) | (c & LOBYTE);
	}
	buf += offs;
	for (i = size - 1; i >= 0; i--)
	{
		c = (buf >> (i * 8)) & LOBYTE;
		putc(c, outf);
	}
	return(position + size);
}





/* finishout 	Finish off the output file by writing out symbol table and
		other stuff */

finishout()
{
	register symp sp;
	register short i;
	register char *cp;

	fseek(tout, sizeof filhdr + tsize + dsize, 0);
	/* MIS STUFF HERE !! */
	if (sflag == 0) 
		for (sp = symtab; sp < &symtab[symindex]; sp++)
		{
		fwrite(&sp->s, sizeof sp->s, 1, tout);
		if ((i = sp->s.n_length) == 0) bletch("zero length symbol");
		cp = sp->sname;
		while (i--)
		{
			if (*cp <= ' ')
				bletch("bad character in symbol %s",
					asciz(sp->sname, sp->s.n_length));
			putc(*cp++, tout);
		}
		if (ferror(tout)) fatal(e14, ofilename);
	}

	/* now actually write out the dstd */
	if (dstdno) {
		fwrite(&dstab[1], sizeof(struct dstdentry), dstdno, tout);
		if (ferror(tout)) fatal(e14, ofilename);
		}
	
	if (rflag)
	{
		fclose(trout);
		fclose(drout);
	}
	fclose(tout);
	fclose(dout);
#ifdef mc68000
	chmod(ofilename, 0777);
#endif
}





/* getfile -	Open an input file as text.  Returns an indicator of the
		magic number of the file but leaves the file pointer at zero.

		Return value:	0 - error (incorrect magic number)
				1 - FMAGIC
				2 - ARCMAGIC
*/


getfile(cp)
register char *cp;	/* name of the file to open */
{
	register short c;
	short magic;

	filename = cp;
	text = NULL;
	if (cp[0]=='-' && cp[1]=='l') {
		if(cp[2] == '\0') cp = "-lc";
		filename = "/usr/lib/libxxxxxxxxxxxxxxx";
		for(c=0; cp[c+2]; c++) 
			filename[c+12] = cp[c+2];
		filename[c+12 ] = '.';
		filename[c+13 ] = 'a';
		filename[c+14 ] = '\0';
		if ((text = fopen(filename+4, "r")) != NULL) filename += 4;
	}
	/* below, both text and rtext are opened on the same input file 
	   for convenience in reading later */
	if (text == NULL && ((text = fopen(filename, "r")) == NULL))
		fatal(e15, filename);
	/*if ((rtext = fopen(filename, "r")) == NULL) fatal(e15, filename);*/
	rtext = fopen(filename, "r"); /* how can we get an error here? */
	dread(&magic, sizeof magic, 1, text);
	fseek(text, 0L, 0);	/* reset file pointer. note rtext not reset */
	return((magic==FMAGIC) ? 1 : (magic==ARCMAGIC) ? 2 : 0);
}






symp *lasthash;	/* saves the result of the last hash call */

/* lookup -	Returns the pointer into symtab of a symbol with the
		same name cursym.sname or NULL if none.
*/

symp lookup()
{
	return(*(lasthash = hash()));
}






/* hash -	Return a pointer to where in the hash table
		a symbol should go.
*/

symp *hash()
{
	register int i;
	register int initial = 0;
	register char *cp = cursym.sname;
	register short j = cursym.s.n_length;

	for (; j-- > 0;)
		initial = (initial<<1) + *cp++;
	
	i = initial =(initial&077777)%NSYM+2;
	while(hshtab[i])
	{
		if (!same(hshtab[i]) || ((cursym.s.n_type & EXTERN) == 0))
		{
			if (++i  == NSYM+2) i = 0;
		}
		else break;
		if (i == initial) fatal(e16);
	}
	return(&hshtab[i]);
}






/* slookup -	Like lookup but with an arbitrary string argument */

symp slookup(s)
char *s;
{
	cursym.sname = s;
	cursym.s.n_length = strlen(s);	/* no trailing 0 */
	cursym.s.n_type = EXTERN+UNDEF;
	cursym.s.n_value = 0;
	return(lookup());
}





/* enter -	Make sure that cursym is installed in symbol table.
		Called with a pointer to a symbol with the same name
		or NULL if lookup failed.  Returns 1 if the symbol
		was new, or 0 if it was already present.
*/

enter(sp, debugflag)
register symp sp;
{
	aligne a1,a2;
	
	if (sp == NULL)
	{
		if (symindex >= NSYM) fatal(e17);
		lastsym = sp = &symtab[symindex];
		if (*lasthash) bletch("hash table conflict");
		*lasthash = sp;
		if((sp->sname = (char *)calloc(1, cursym.s.n_length)) == NULL)
		  fatal(e17);
		acopy(sp->sname);
		if (*(sp->sname) == 0) bletch("null symbol entered");
		sp->s.n_length = cursym.s.n_length;
		sp->s.n_type = cursym.s.n_type;
		sp->s.n_value = cursym.s.n_value;
		sp->shash = lasthash;
		sp->sindex = symindex++;
		if ((sp->s.n_type&ALIGN) && !rflag)
		{
			if ((a1 = (aligne)calloc(1, sizeof(*a1))) == NULL)
				fatal(e17);
			a1->modulo = cursym.s.n_unit;
			/* n_unit is being bastardized here as the mod factor
			   sent from the assembler. This should be the only
			   time that the assembler uses this field. */
			a1->symp = sp;
			a1->nextale = NULL;
			if (alptr == NULL) alptr = a1;
			else
			{
				for (a2 = alptr;a2->nextale; a2=a2->nextale) ;
				a2->nextale = a1;
			}
		}
		sp->s.n_unit = (rflag) ? cursym.s.n_unit : (debugflag>1) ?
					 dstdno : 0;
		/* if (debugflag>1) ; */	/* do cross referencing
					   between LEST and DST */
		return(1);
	}
	else 
	{
		lastsym = sp;
		return(0);
	}
}





/* symreloc -	Perform partial relocation of symbol.  Each symbol is
		relocated twice.  The first time, it is adjusted to
		is relative position within its segment.  The second
		time, it is adjusted by the start of the final segment
		to which that symbol refers.  This routine only
		performs the first relocation.
 */

symreloc()
{
	switch (cursym.s.n_type) {

	case TEXT:
	case EXTERN+TEXT:
	case EXTERN+TEXT+ALIGN:
		cursym.s.n_value += ctrel;
		return;

	case DATA:
	case EXTERN+DATA:
	case EXTERN+DATA+ALIGN:
		cursym.s.n_value += cdrel;
		return;

	case BSS:
	case EXTERN+BSS:
	case EXTERN+BSS+ALIGN:
		cursym.s.n_value += cbrel;
		return;

	case EXTERN+UNDEF:
		return;
	}
	if (cursym.s.n_type&EXTERN)
		cursym.s.n_type = EXTERN+ABS;
}





/* readhdr -	Read in an a.out header, adjusting relocation offsets */
readhdr(pos)
long pos;
{
	register long st, sd;
	
	fseek(text, pos, 0);
	dread(&filhdr, sizeof filhdr, 1, text);
	if ((filhdr.a_magic != FMAGIC) || (filhdr.a_machine != MC68000))
		error(e5, filename);
	st = (filhdr.a_text+1) & ~1;
	filhdr.a_text = st;
	cdrel = -st;
	sd = (filhdr.a_data+1) & ~1;
	cbrel = - (st + sd);
	filhdr.a_bss = (filhdr.a_bss+1) & ~1;
}	





/* getsym -	Read in a symbol from txt, leaving data in cursym.  Return
		length of stuff read in. */

long getsym()
{
	register int c;
	register int i;

	/* read upto name */
	fread(&cursym.s, sizeof cursym.s, 1, text);
	if (feof(text)) fatal(e3, filename);
	for (i = 0; i < cursym.s.n_length; i++)
	{
		if ((c = getc(text)) == EOF) fatal(e3, filename);
		else if ((csymbuf[i] = c) == 0) fatal(e22, filename, csymbuf);
	}
	cursym.sname = csymbuf;
	return(sizeof(cursym.s) + i);
}






/* error -	Print out error messages and give up if they are severe. */

/*VARARGS1*/
error(fmt, a1, a2, a3, a4, a5)
char *fmt;
{
	printf("ld: ");
	printf(fmt, a1,a2,a3,a4,a5);
	printf("\n");
}







/* fatal -	Print error message and exit */

/*VARARGS1*/
fatal(fmt, a1, a2, a3, a4, a5)
char *fmt;
{
	error(fmt, a1, a2, a3, a4, a5);
	exit(1);
}







/* bletch -	Print out a message and abort.  Used for internal errors. */

/*VARARGS1*/
bletch(fmt, a1, a2, a3, a4, a5)
char *fmt;
{
	error(fmt, a1, a2, a3, a4, a5);
	abort();
}





/* dread -	Like fread but checks for errors and eof */

dread(pos, size, count, file)
char *pos;
int size;
int count;
register FILE *file;
{
	if (fread(pos, size, count, file) == size * count) return;
	if (feof(file)) fatal(e3, filename);
	if (ferror(file)) fatal(e4, filename);
}






/* dcopy -	Copy input to output, checking for errors */

dcopy(in, out, count)
register FILE *in, *out;
register long count;
{
	register int c;

	if (count < 0) bletch("bad count to dcopy");
	while(count--)
	{
		if ((c = getc(in)) == EOF)
		{
			if (feof(in)) fatal(e3, filename);
			if (ferror(out)) fatal(e4, filename);
		}
		putc(c, out);
	}
}




/* same - returns 1 if two ascii strings are alike. Otherwise returns 0. */

same(sp)
register symp sp;

{register short i;
 register char *c1, *c2;

if (sp->s.n_length != cursym.s.n_length) return(0);
for (i=sp->s.n_length, c1=sp->sname, c2=cursym.sname; i>0; i--)
	if (*c1++ != *c2++) return(0);
return(1);
}





/* acopy - copies ascii names from cursym.sname (no null terminator). */

acopy(sp)
register char *sp;
{register char i = cursym.s.n_length;
 register char *ss = cursym.sname;

 for (; i>0; i--) *sp++ = *ss++;
 return;
}






char ascizs[SYMLENGTH];


/* asciz returns the location of an asciz version of an ascii string for
   printing */

char *asciz(sp, l)
register char *sp;
register int l;
{register int i = 0;
 for (; l >0; l--) ascizs[i++] = *sp++;
 ascizs[i] = 0;
 return(ascizs);
}

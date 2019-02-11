/*
 * ld.c - 68000 Linking Loader
 *
 * July 1982 Bill Nowicki Stanford
 *	- merged LucasFilms and Stanford versions
 *	- made symbol table larger
 */

#ifdef BOOTSTRAP
#include "/usr/include/stdio.h"
#else
#include <stdio.h>
#endif

#ifndef Stanford
				/* Unix -specific stuff */
#include <sys/autoconf.h>	/* to get U_VA */
#include <a.out.h>
#include <ar.h>			/* V7 archive header */
#include <ar.bky.h>		/* UC Berkeley archive header */
#include <bootstrap.h>

#else Stanford

#include <b.out.h>
#include <ar.h>		/* UC Berkeley archive header */
#define ROOT "/usr/sun"

#endif Stanford

/*
 *  link editor
 */

#define TRUE 1
#define FALSE 0

/*  Warning!  segsize is assumed to be <= the largest segment size 
 *  in any hardware implmentation.  segsize determines where the
 *  data/bss segment is placed in mode 410 files (seperate R/O text segment).
 *  It MUST agree with a similar definition in the kernel (machdep.c).
 */

#define	segsize	64*1024		/* text/data segment seperate size */

struct archdir				/* Don't use this on UCB Unix */
{
	char	aname[14];
	long	atime;
	char	auid, agid;
	short	amode;
	long	asize;
};

#define NOVLY	16
#define	NROUT	256
#define	NSYM	4507		/* symbol table size */
				/* LucasFlim had 4000, MIT had 1503 */
#define	NSYMPR	1200
#define TABSZ	700
#ifndef Stanford
#define ORG	U_VA		/* default text origin */
#else Stanford
#define ORG	0x1000
#endif Stanford

#ifdef BOOTSTRAP
#define	DOTOUT	"b.out"
#define	BIN	'b'
#else
#define	DOTOUT	"a.out"
#define	BIN	'o'
#endif

typedef struct symbol *symp;
struct symbol
{
	struct sym s;			/* type and value */
	char *sname;			/* pointer to asciz name */
	int snlength;			/* length of name in bytes */
	symp *shash;			/* hash table index */
	unsigned sindex;		/* id of symbol in symtab */
};

typedef struct arg_link *arg;
struct arg_link
{
	char *arg_name;			/* the acutal argument string */
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
/* global variables */

arg arglist;				/* linked list of arguments */
#ifndef Stanford
struct ar_hdr v7_archdr;		/* directory part of v7 archive */
struct bky_ar_hdr bky_archdr;		/* directory part of bky archive */
#else Stanford
struct ar_hdr archdr;			/* directory part of archive */
#endif Stanford
arcp arclist = NULL;			/* list of archives */
arcp arclast = NULL;			/* last archive on arclist */
arce arcelast = NULL;			/* last entry in this entry list */
#ifndef Stanford
struct exec filhdr;			/* header file for current file */
#else Stanford
struct bhdr filhdr;			/* header file for current file */
#endif Stanford
struct symbol cursym;			/* current symbol */
char csymbuf[SYMLENGTH];		/* buffer for current symbol name */
struct symbol symtab[NSYM];		/* actual symbols */
symp lastsym;				/* last symbol entered */
int symindex;				/* next available symbol table entry */
symp hshtab[NSYM+2];			/* hash table for symbols */
symp local[NSYMPR];			/* symbols in current file */
int nloc;				/* number of local symbols per file */
int nund = 0;				/* number of undefined syms in pass 2*/
symp entrypt = 0;			/* pointer to entry point symbol */
int argnum;				/* current argument number */
char *ofilename = DOTOUT;		/* output file, default init */

FILE *text;				/* file descriptor for input file */
FILE *rtext;				/* used to access relocation */
char *filename;				/* name of current input file */
char *mfilename;			/* name of Macsbug input file */

char tfilename[100];			/* copy of filename */
char xfilename[100];			/* copy of filename */

FILE *tout;				/* text portion */
FILE *dout;				/* data portion */
FILE *trout;				/* text relocation commands */
FILE *drout;				/* data relocation commands */
FILE *Lout;				/* list symbols */


/* flags */
int	xflag;		/* discard local symbols */
int	Xflag;		/* discard locals starting with '.L' */
int	Sflag;		/* discard all except locals and globals*/
int	rflag;		/* preserve relocation bits, don't define common */
int	sflag;		/* discard all symbols */
int	vflag=1;	/* what version? presently default to 1 */
int	dflag;		/* define common even with rflag */
int	Lflag;		/* list symbols on list.out */
int	nflag = 0;	/* create a 410 file */
int	Bflag;		/* set origin of common/bss segment */

/* used after pass 1 */
long torigin;		/* origin of text segment in final output */
long dorigin;		/* origin of data segment in final output */
long doffset;		/* current position in output data segment */
long borigin;		/* origin of bss segment in final output */
long corigin;		/* origin of common area */

/* cumulative sizes set in pass 1 */
long	tsize;		/* size of text data */
long	dsize;		/* size of data segment */
long	bsize;		/* size of bss segment */
long	csize;		/* size of common area */
long	rtsize;		/* size of text relocation area */
long	rdsize;		/* size of data relocation area */
long	ssize = 0;	/* size of symbol area */

/* symbol relocation; both passes */
long	ctrel;
long	cdrel;
long	cbrel;

/* error messages */

char *e1 = "missing argument following command option -%c";
char *e2 = "unrecognized option: -%c";
char *e3 = "premature end of file %s";
char *e4 = "read error on file %s";
char *e5 = "unknown type of file %s";
char *e5a = "unknown type of file %s in readhdr";
char *e6 = "multiply defined symbol %s in file %s";
char *e7 = "entry point not in text";
char *e8 = "cannot create file %s";
char *e9 = "cannot reopen output file";
char *e10 = "local symbol overflow";
char *e11 = "internal error - undefined symbol %s in file %s";
char *e12 = "format error in file %s, bad relocation size";
char *e13 = "format error in file %s, relocation outside of segment";
char *e14 = "error writing file %s";
char *e15 = "file %s not found";
char *e16 = "hash table overflow";
char *e17 = "symbol table overflow";
char *e18 = "format error in file %s, null symbol name";
char *e19 = "format error in file %s, invalid symbol id in relocation command";
char *e20 = "%s references %s";
char *e21 = "format error in file %s, bad address in relocation command";
char *e22 = "bad header in archive %s, ARFMAG is 0x%x 0x%x";
char *e23 = "unknown archive magic, 0x%x 0x%x 0x%x 0x%x";

/* functions */

long getsym();
symp lookup();
symp slookup();
symp *hash();
long relext();
long relcmd();
long atox();
/* main -	The link editor works in two passes.  In pass 1, symbols
		are defined.  In pass 2, the actual text and data will
		be output along with any relocation commands and symbols
*/

main(argc, argv)
int argc;
char **argv;
{
	arg argp;	/* current argument */
	
	torigin = ORG;	/* set with -T flag */
	procargs(argc, argv);
	for (argp = arglist; argp; argp = argp->arg_next)
		load1arg(filename = argp->arg_name);
	middle();
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
}


/* newarg -	Create a new member of linked list of arguments
 */
newarg(name)
char *name;
{
	arg a1, a2;
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
int argc;
char **argv;
{
	char *flagp = &argv[argnum][1];
	char c;

	while(c = *flagp++) switch(c)
	{
	case 'o':
		if (++argnum >= argc) error(e1, c);
		else ofilename = argv[argnum];
		break;
	case 'u':
		if (++argnum >= argc) error(e1, c);
		else enter(slookup(argv[argnum]));
		break;
	case 'e':
		if (++argnum >= argc) error(e1, c);
		else enter(slookup(argv[argnum]));
		entrypt = lastsym;
		break;
	case 'D':
		if (++argnum >= argc) error(e1, c);
		else dsize = atol(argv[argnum]);
		break;
	case 'T':
		if (++argnum >= argc) error(e1, c);
		else torigin = atox(argv[argnum]);
		break;
	case 'B':
		if (++argnum >= argc) error(e1, c);
		else borigin = atox(argv[argnum]);
		Bflag++;
		break;

	case 'l': newarg(argv[argnum]); while (*++flagp); break;
	case 'x': xflag++; break;
	case 'X': Xflag++; break;
	case 'S': Sflag++; break;
	case 'r': rflag++; break;
	case 's': sflag++; xflag++; break;
	case 'v': vflag = *flagp++; break;
	case 'd': dflag++; break;
	case 'n': nflag++; break;
	case 'L': Lflag++; break;
	case 'M': Lflag++; break;
	default:	error(e2, c);
	}
}

long atox(s)
char *s;
{
	long result = 0;
	for (; *s != 0; *s++)
	  if (*s >= '0' && *s <= '9') result = (result<<4) + *s-'0'; else
	  if (*s >= 'a' && *s <= 'f') result = (result<<4) + *s-'a'+10; else
	  if (*s >= 'A' && *s <= 'F') result = (result<<4) + *s-'A'+10; else
	  error("atox: illegal hex argument (%c)",*s);
	return(result);
}
/* scan file to find defined symbols */
load1arg(cp)
register char *cp;
{
	long position = 0, n;
	arcp ap;		/* pointer to new archive list element */

	switch (getfile(cp))	/* open file and read first word */
	{
	case FMAGIC:
		fseek(text, 0L, 0);	/* back to start of file */
		load1(0L, 0);		/* pass1 on regular file */
		break;

#ifndef Stanford
	/* V7 archive */
	case ARMAG:
#else Stanford
	/* regular archive */
	case ARCMAGIC:
#endif Stanford
		ap = (arcp)calloc(1, sizeof(*ap));
		ap->arc_next = NULL;
		ap->arc_e_list = NULL;
		if (arclist)
		{
			arclast->arc_next = ap;
			arclast = ap;
		}
		else arclast = arclist = ap;
#ifndef Stanford
		position = 2;
		fseek(text, 2L, 0);		/* skip magic */
		while (fread(&v7_archdr, sizeof v7_archdr, 1, text) &&
		      !feof(text))
#else Stanford
		position = SARMAG;
		fseek(text, SARMAG, 0);		/* skip magic */
		while (fread(&archdr, sizeof archdr, 1, text) && !feof(text))
#endif Stanford
		{
#ifndef Stanford
			position += sizeof(v7_archdr);
#else Stanford
			position += sizeof(archdr);
#endif Stanford
			if (load1(position, 1))		/* arc pass1 */
			{
				arce ae = (arce)calloc(1, sizeof(*ae));
				ae->arc_e_next = NULL;
				ae->arc_offs = position;
				if (arclast->arc_e_list)
				{
					arcelast->arc_e_next = ae;
					arcelast = ae;
				}
				else arclast->arc_e_list = arcelast = ae;
			}
#ifndef Stanford
			position += (v7_archdr.ar_size+1)&~1;
			fseek(text, position, 0);
		}
		break;

	/* Berkeley archive */
	case BKYARCHIVE:
		ap = (arcp)calloc(1, sizeof(*ap));
		ap->arc_next = NULL;
		ap->arc_e_list = NULL;
		if (arclist)
		{
			arclast->arc_next = ap;
			arclast = ap;
		}
		else arclast = arclist = ap;
		position = BKYSARMAG;
		fseek(text, BKYSARMAG, 0);		/* skip magic */
		while (fread(&bky_archdr, sizeof bky_archdr, 1, text) &&
		      !feof(text)) {
			if (strcmpn(bky_archdr.bky_fmag, BKYARFMAG,
			    sizeof BKYARFMAG) != 0)
				fatal (e22, filename, bky_archdr.bky_fmag[0],
					bky_archdr.bky_fmag[1]);
			position += sizeof(bky_archdr);
			if (load1(position, 1))		/* arc pass1 */
			{
				arce ae = (arce)calloc(1, sizeof(*ae));
				ae->arc_e_next = NULL;
				ae->arc_offs = position;
				if (arclast->arc_e_list)
				{
					arcelast->arc_e_next = ae;
					arcelast = ae;
				}
				else arclast->arc_e_list = arcelast = ae;
			}
			sscanf(bky_archdr.bky_size,"%d",&n);
#else Stanford
			sscanf(archdr.ar_size,"%d",&n);
#endif Stanford
			position += (n+1)&~1;
			fseek(text, position, 0);
		}
		break;

	default:
		fatal(e5, filename);
	}
	fclose(text);
	fclose(rtext);
}
/* load1 -	Accumulate file sizes and symbols for single file
		or archive member.  Relocate each symbol as it is
		processed to its relative position in it csect.
		If libflg == 1, then file is an archive hence
		throw it away unless it defines some symbols.
		Here we also accumulate .comm symbol values.
*/

load1(sloc, libflg)
long sloc;	/* location of first byte of this file */
int libflg;	/* 1 => loading a library, 0 else */
{
	long loc = sloc;/* current position in file */
	long endpos;	/* position after symbol table */
	int savindex;	/* symbol table index on entry */
	int ndef;	/* number of symbols defined */

	readhdr(sloc);

	ctrel = tsize;
	cdrel += dsize;
	cbrel += bsize;
	ndef = 0;
	nloc = 0;
	savindex = symindex;
	loc += SYMPOS;
	fseek(text,loc, 0);	/* skip to symbols */
	endpos = loc + filhdr.ssize;
	while (loc < endpos)
	{
		loc += getsym();
		ndef += sym1();	/* process one symbol */
	}
	if (libflg==0 || ndef) {
		tsize += filhdr.tsize;
		dsize += filhdr.dsize;
		bsize += filhdr.bsize;
		ssize += nloc;			/* count local symbols */
		rtsize += filhdr.rtsize;
		rdsize += filhdr.rdsize;
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
	int type = cursym.s.stype;	/* type of the current symbol */
#ifdef Stanford
	int len = cursym.s.slength;	/* length of the current symbol */
#endif Stanford

	if (Sflag) switch(type& 037)
	{
	case TEXT:
	case BSS:
	case DATA:
		break;
	default:
		return(0);
	}
	if ((type&EXTERN) == 0)
	{
		if (xflag || (Xflag && (cursym.sname[0] == '.')
			&& (cursym.sname[1] == 'L')));
		else nloc += sizeof(cursym.s) + cursym.snlength + 1;
		return(0);
	}
	symreloc(); 			/* relocate symbol in file */
	if (enter(lookup())) return(0);	/* install symbol in table */

	/* If we get here, then symbol was already present.
	   If symbol is already defined then return, multiple
	   definitions are caught later.   If current symbol is
	   not EXTERN eg it is local, let the new one override */

	if ((sp = lastsym)->s.stype & EXTERN)
	{
		if ((sp->s.stype & 037) != UNDEF) return(0);
	}
	else if (!(cursym.s.stype & EXTERN)) return(0);
	if (cursym.s.stype == EXTERN+UNDEF)
	{
		/* check for .comm symbols */
		if (cursym.s.svalue>sp->s.svalue) sp->s.svalue=cursym.s.svalue;
		return(0);
	}
	if (sp->s.svalue!=0 && cursym.s.stype == EXTERN+TEXT) return(0);
	sp->s.stype = cursym.s.stype;	/* define something new */
#ifdef Stanford
	sp->s.slength = cursym.snlength;
#endif Stanford
	sp->s.svalue = cursym.s.svalue;
	return(1);
}
/* middle -	Finalize the symbol table by adding the origins of
		each csect to symbols.  Also define the end stuff,
		adjusting the boundries of the csect depending on
		options.
 */

middle()
{
	register symp sp;
	int col=1, Lokay=TRUE;

	enter(slookup("_etext"));
	enter(slookup("_edata"));
	enter(slookup("_end"));
	/*
	 * Assign common locations.
	 */
	csize = 0;
	if (dflag || rflag==0)
	{
		ldrsym(slookup("_etext"), tsize, EXTERN+TEXT); /* set value */
		ldrsym(slookup("_edata"), dsize, EXTERN+DATA);
		ldrsym(slookup("_end"), bsize, EXTERN+BSS);
		common();
	}
	/*
	 * Now set symbols to their final value
	 */
#ifndef Stanford
	tsize = (tsize + 1) & ~01;		/* move to word boundary */

	/* move data/bss segment up to segment boundary for mode 410 files */

	if (nflag) dorigin = torigin + ((tsize + (segsize-1)) & ~(segsize-1));

#else Stanford
	tsize += tsize&1;			/* move to word boundry */
	if (nflag) {				/* -n -> move to seg bdy */
		torigin = torigin + (SEGSIZE - 1) & -SEGSIZE;
		dorigin = torigin+(tsize+(SEGSIZE - 1)) & -SEGSIZE;
	}
#endif Stanford
	else dorigin = torigin + tsize;
#ifndef Stanford
	dsize = (dsize + 1) & ~01;		/* move to word boundary */
	if (Bflag) {
		corigin = borigin;		/* put comm/bss elsewhere */
		borigin += csize;
	} else {
#else Stanford
	dsize += dsize&1;			/* move to word boundry */
#endif Stanford
		corigin = dorigin + dsize;	/* common after data */
		borigin = corigin + csize;	/* bss after common area */
#ifndef Stanford
	}
#endif Stanford
	nund = 0;				/* no undefined initially */
/*	ssize = size of local symbols to be entered in load2		*/
	doffset = 0;				/* beginning of data seg */
	Lokay = TRUE;
	if (Lflag)
	   if ((Lout = fopen("sym.out", "w")) == NULL)
	      {error(e8, "list.out");
	       Lokay = FALSE;
	      }
	for (sp = symtab; sp < &symtab[symindex]; sp++)  
	    {sym2(sp);
	     if (Lokay && Lflag)
		fprintf(Lout, col++%4?"%s %x\t":"%s %x\n",
			sp->sname, sp->s.svalue);
	    }
	bsize += csize;
}
/* common -	Set up the common area.
 */

common()
{
	register symp sp;
	long val;

	csize = 0;
	for (sp = symtab; sp < &symtab[symindex]; sp++)
		if (sp->s.stype == EXTERN+UNDEF && ((val = sp->s.svalue) != 0))
		{
			val = (val + 1) & ~01;	/* word boundry */
			sp->s.svalue = csize;
			sp->s.stype = EXTERN+COMM;
			csize += val;
		}
}
/* sym2 -	Assign external symbols their final value and compute ssize */
sym2(sp)
register symp sp;
{
	ssize += sizeof(sp->s) + sp->snlength + 1;
	switch (sp->s.stype)
	{
	case EXTERN+UNDEF:
		if ((rflag == 0 || dflag) && sp->s.svalue == 0)
		{
			if (nund==0)
				printf("Undefined:\n");
			nund++;
			printf("%s\n", sp->sname);
		}
		break;

	case EXTERN+ABS:
	default:
		break;

	case EXTERN+TEXT:
		sp->s.svalue += torigin;
		break;

	case EXTERN+DATA:
		sp->s.svalue += dorigin;
		break;

	case EXTERN+BSS:
		sp->s.svalue += borigin;
		break;

	case EXTERN+COMM:
		sp->s.stype = EXTERN+BSS;
		sp->s.svalue += corigin;
		break;
	}
}
/* ldrsym -	Force the definition of a symbol */
ldrsym(asp, val, type)
symp asp;
long val;			/* value of the symbol */
char type;			/* its type */
{
	register symp sp;

	if ((sp = asp) == 0)
		return;
	if (sp->s.stype != EXTERN+UNDEF || sp->s.svalue)
	{
		error(e6, sp->sname, filename);
		return;
	}
	sp->s.stype = type;
	sp->s.svalue = val;
}

/* setupout -	Set up for output.  Create output file and a temporary
		files for the data area and relocation commands if
		necessary.  Write the header on the output file.
 */

setupout()
{
	if (nflag) filhdr.fmagic = NMAGIC;
	else filhdr.fmagic = FMAGIC;
	filhdr.tsize = tsize;
	filhdr.dsize = dsize;
	filhdr.bsize = bsize;
	filhdr.rtsize = rflag? rtsize: 0;
	filhdr.rdsize = rflag? rdsize: 0;
	filhdr.ssize = sflag? 0:ssize;
	if (!entrypt && slookup("_start") != NULL)
	     entrypt = slookup("_start");
	if (entrypt)
	{
		if (entrypt->s.stype!=EXTERN+TEXT) error(e7);
		else filhdr.entry = entrypt->s.svalue;
	}
	else filhdr.entry = torigin;
	if ((tout = fopen(ofilename, "w")) == NULL) fatal(e8, ofilename);
	if ((dout = fopen(ofilename, "a")) == NULL) fatal(e9);
	fseek(dout, (long)(DATAPOS), 0);
	if (rflag)
	{
		if ((trout = fopen(ofilename, "a")) == NULL) fatal(e9);
		fseek(trout, (long)RTEXTPOS, 0); /* start of text relocation */
		if ((drout = fopen(ofilename, "a")) == NULL) fatal(e9);
		fseek(drout, (long)RDATAPOS, 0);	/* to data reloc */
	}
	fwrite(&filhdr, sizeof(filhdr), 1, tout);
}
/* load2arg -	Load a named file or an archive */

load2arg(cp)
char *cp;
{
	long position = 0;	/* position in input file */
	arce entry;		/* pointer to current entry */
	switch (getfile(cp))
	{
	case FMAGIC:			/* normal file */
		
		dread(&filhdr, sizeof filhdr, 1, text);
		load2(0L);
		break;
#ifndef Stanford
	case ARMAG:			/* V7 archive */
#else Stanford
	case ARCMAGIC:			/* archive */
#endif Stanford
		for(entry=arclist->arc_e_list; entry; entry=entry->arc_e_next)
		{
			position = entry->arc_offs;
			fseek(text, position, 0);
			dread(&filhdr, sizeof filhdr, 1, text);
			load2(position);		/* load the file */
		}
		arclist = arclist->arc_next;
		break;
#ifndef Stanford

	case BKYARCHIVE:			/* Berkeley archive */
		for(entry=arclist->arc_e_list; entry; entry=entry->arc_e_next)
		{
			position = entry->arc_offs;
			fseek(text, position, 0);
			dread(&filhdr, sizeof filhdr, 1, text);
			load2(position);		/* load the file */
		}
		arclist = arclist->arc_next;
		break;

#endif Stanford
	default:	bletch("bad file type on second pass");
	}
	fclose(text);
	fclose(rtext);
}

/* load2 -	Actually output the text, performing relocation as necessary.
 */
load2(sloc)
long sloc;	/* position of filhdr in current input file */
{
	register symp sp;
	long loc=sloc;	/* current position in file */
	long endpos;	/* end of symbol segment */
	int symno = 0;
	int type;

	readhdr(sloc);
	ctrel = torigin;
	cdrel += dorigin;
	cbrel += borigin;

	/*
	 * Reread the symbol table, recording the numbering
	 * of symbols for fixing external references.
	 */
	loc += SYMPOS;
	fseek(text, loc, 0);
	endpos = loc + filhdr.ssize;
	while(loc < endpos)
	{
		loc += getsym();
		symno++;
		if (symno >= NSYMPR) fatal(e10);
		symreloc();
		type = cursym.s.stype;
		if (Sflag)
		{
			switch(type&037)
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
			if (xflag || (Xflag && (cursym.sname[0] == '.')
				&& (cursym.sname[1] == 'L')));
			else enter(lookup());
			continue;
		}
		if ((sp = lookup()) == NULL) fatal(e11,cursym.sname,filename);
		local[symno - 1] = sp;
		if (cursym.s.stype != EXTERN+UNDEF
		 && (cursym.s.stype != sp->s.stype
		  || cursym.s.svalue != sp->s.svalue))
			error(e6, cursym.sname, filename);
	}
	fseek(text, sloc+TEXTPOS, 0);
	fseek(rtext, sloc+RTEXTPOS, 0);
	load2td(tout, trout, torigin, filhdr.tsize, filhdr.rtsize);
	fseek(text, sloc+DATAPOS, 0);
	fseek(rtext, sloc+RDATAPOS, 0);
	load2td(dout, drout, doffset, filhdr.dsize, filhdr.rdsize);
	torigin += filhdr.tsize;
	dorigin += filhdr.dsize;
	doffset += filhdr.dsize;
	borigin += filhdr.bsize;
}
/* load the text or data section of a file performing relocation */
load2td(outf, outrf, txtstart, txtsize, rsize)
FILE *outf;		/* text or data portion of output file */
FILE *outrf;		/* text or data relocation part of output file */
long txtstart;		/* initial offset of text or data segment */
long txtsize;		/* number of bytes in segment */
long rsize;		/* size of appropriate relocation data */
{
	struct reloc rel;		/* the current relocation command */
	int size;			/* number of bytes to relocate */
	long offs;			/* value of offset to use */
	long rcount;			/* number of relocation commands */
	long pos = 0;			/* current input position */

	rcount = rsize/sizeof rel;
	while(rcount--)			/* for each relocation command */
	{
		if (pos >= txtsize) bletch("relocation after end of segment");
		dread(&rel, sizeof rel, 1, rtext);
		switch(rel.rsegment)
		{
		case REXT:
			offs = relext(&rel);
			break;
		case RTEXT:
			offs = torigin;
			break;
		case RDATA:
			offs = dorigin - filhdr.tsize;
			break;
		case RBSS:
			offs = borigin - (filhdr.tsize + filhdr.dsize);
			break;
		}
		if (rel.rdisp)
			offs -= rel.rpos + txtstart;
		switch(rel.rsize)
		{
		case RBYTE:
			size = 1; break;
		case RWORD:
			size = 2; break;
		case RLONG:
			size = 4; break;
		default:
			fatal(e12, filename);
		}
		if (rel.rpos > txtsize) fatal(e13, filename);
		else pos = relcmd(pos, rel.rpos, size, offs, outf);
		if (rflag && rel.rdisp==0)	/* write out relocation commands */
		{
			rel.rpos +=  txtstart;
			rel.rsymbol = (rel.rsegment == REXT)?
				local[rel.rsymbol]->sindex: 0;
			fwrite(&rel, sizeof rel, 1, outrf);
		}
	}
	dcopy(text, outf, txtsize - pos);
}
/* relext -	Find the offset of an REXT command and fix up the rel cmd.
 */

long relext(r)
register struct reloc *r;
{
	register symp sp;		/* pointer to symbol for EXT's */
	long offs;			/* return value */

	if ((r->rsymbol < 0 || r->rsymbol >= NSYMPR) ||
		((sp = local[r->rsymbol]) == NULL))
	{
		error(e19, filename);
		offs = 0;
	}
	else
	{
		offs = sp->s.svalue;
		switch(sp->s.stype & 037)
		{
		case TEXT: r->rsegment = RTEXT; break;
		case DATA: r->rsegment = RDATA; break;
		case BSS: r->rsegment = RBSS; break;
		case UNDEF:
			if (rflag && (sp->s.stype & EXTERN)) {
				r->rsegment = REXT;
				break;
			}
		default: error(e20, filename, sp->sname);
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
long offs;		/* the number to fix up by */
FILE *outf;		/* where to write to */
{
	register int i, c;
	long buf = 0;
	if (position < current)
	{
		error(e21, filename);
		return(current);
	}
	dcopy(text, outf, position - current);
	for (i = 0; i < size; i++)
	{
		if ((c = getc(text)) == EOF) fatal(e3, filename);
		buf = (buf << 8) | (c & 0377);
	}
	buf += offs;
	for (i = size - 1; i >= 0; i--)
	{
		c = (buf >> (i * 8)) & 0377;
		putc(c, outf);
	}
	return(position + size);
}
/* finishout 	Finish off the output file by writing out symbol table */

finishout()
{
	register symp sp;

	fseek(tout, sizeof filhdr + tsize + dsize, 0);
	if (sflag == 0) for (sp = symtab; sp < &symtab[symindex]; sp++)
	{
		register int i;
		register char *cp;

		fwrite(&sp->s, sizeof sp->s, 1, tout);
		if ((i = sp->snlength) == 0) bletch("zero length symbol");
		cp = sp->sname;
		while (i--)
		{
			if (*cp <= ' ')
				bletch("bad character in symbol %s",sp->sname);
			putc(*cp++, tout);
		}
		putc('\0', tout);
		if (ferror(tout)) fatal(e14, ofilename);
	}
	fclose(tout);
	fclose(dout);
	if (rflag)
	{
		fclose(trout);
		fclose(drout);
	}
#ifndef Stanford
	if(nund==0)
		chmod(ofilename, 0777);
#endif Stanford
}
/* getfile -	Open an input file as text.  Returns the first word of
		file but leaves the file pointer at zero */
getfile(cp)
register char *cp;	/* name of the file to open */
{
	register int c;
	long magic;
#ifndef Stanford
	char smagic[BKYSARMAG];
#endif Stanford

#ifndef Stanford
	v7_archdr.ar_name[0] = '\0';
	bky_archdr.bky_name[0] = '\0';
#else Stanford
	archdr.ar_name[0] = '\0';
#endif Stanford
	filename = cp;
	text = NULL;
	if (cp[0]=='-' && cp[1]=='l') {
		if(cp[2] == '\0') cp = "-la";

		strcpy(xfilename, ROOT);
		strcat(xfilename,"/lib/lib");
		filename = xfilename;
		strcpy(filename+strlen(xfilename),cp+2);
		strcat(filename,".a");
		if (vflag=='m') {
			mfilename = "/usr/sun/dm/lib/libxxxxxxxxxxxxxxx";
			strcpy(mfilename+19,cp+2);
			strcat(mfilename,".a");
			if ((rtext=fopen(mfilename)) != NULL) {
				fclose(rtext);
				strcpy(filename,mfilename);
			}
		}
	}
	strcpy(tfilename,filename);
	{int len = strlen(tfilename);
	 if (len < 3 
	     || tfilename[len-1] != BIN && tfilename[len-1] != 'a'
	     || tfilename[len-2] != '.') {
	    strcat(tfilename,".");
	    strcat(tfilename,BIN);
	  }
	}

	if (text == NULL && (text = fopen(tfilename, "r")) == NULL)
		fatal(e15, filename);
	if ((rtext = fopen(tfilename, "r")) == NULL)
		fatal(e15, filename);
	dread(&magic, sizeof magic, 1, text);
#ifndef Stanford
	fseek(text, 0L, 0);
	if ((magic == FMAGIC) || ((magic>>16) == ARMAG))
		return (magic);
	dread(smagic, sizeof smagic, 1, text);
	if (strcmpn(smagic, BKYARMAG, sizeof smagic) == 0)
		return (BKYARCHIVE);
	fatal(e23, smagic[0], smagic[1], smagic[2], smagic[3]);
#else Stanford
	fseek(text, 0L, 0);	/* reset file pointer */
	return magic == FMAGIC || magic == ARCMAGIC? magic: 0;
#endif Stanford
}

/* lookup -	Returns the pointer into symtab of a symbol with the
		same name cursym.sname or NULL if none.
 */

symp lookup()
{
	return(*hash(cursym.sname));
}

/* hash -	Return a pointer to where in the hash table
		a symbol should go.
*/

symp *hash(s)
char *s;
{
	register int i = 0, cmpv;
	register int initial;
	register char *cp;

	i = 0;
	for (cp = s; *cp;) i = (i<<1) + *cp++;
	
	initial = i =(i&077777)%NSYM+2;
	while(hshtab[i])
	{
		cmpv = strcmp(hshtab[i]->sname, cursym.sname);
		if ((cmpv != 0) || ((hshtab[i]->s.stype & EXTERN) == 0))
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
	cursym.snlength = strlen(s);
	cursym.s.stype = EXTERN+UNDEF;
	cursym.s.svalue = 0;
	return(lookup());
}

/* enter -	Make sure that cursym is installed in symbol table.
		Called with a pointer to a symbol with the same name
		or NULL if lookup failed.  Returns 1 if the symbol
		was new, or 0 if it was already present.
*/

enter(sp)
register symp sp;
{
	symp *hp;		/* pointer to place in hash table */
	if (sp == NULL)
	{
		hp = hash(cursym.sname);
		if (symindex>=NSYM) fatal(e17);
		lastsym = sp = &symtab[symindex];
		if (*hp) bletch("hash table conflict");
		*hp = sp;
		if((sp->sname = (char *)calloc(1, cursym.snlength+1)) == NULL)
		  fatal(e17);
		strcpy(sp->sname, cursym.sname);
		if (*(sp->sname) == 0) bletch("null symbol entered");
#ifndef Stanford
		sp->snlength = cursym.snlength;
#else Stanford
		sp->s.slength = sp->snlength = cursym.snlength;
#endif Stanford
		sp->s.stype = cursym.s.stype;
		sp->s.svalue = cursym.s.svalue;
		sp->shash = hp;
		sp->sindex = symindex++;
		return(1);
	}
	else 
	{
		lastsym = sp;
		return(0);
	}
}

/* symrel -	Perform partial relocation of symbol.  Each symbol is
		relocated twice.  The first time, it is adjusted to
		is relative position within its segment.  The second
		time, it is adjusted by the start of the final segment
		to which that symbol refers.  This routine only
		performs the first relocation.
 */

symreloc()
{
	switch (cursym.s.stype) {

	case TEXT:
	case EXTERN+TEXT:
		cursym.s.svalue += ctrel;
		return;

	case DATA:
	case EXTERN+DATA:
		cursym.s.svalue += cdrel;
		return;

	case BSS:
	case EXTERN+BSS:
		cursym.s.svalue += cbrel;
		return;

	case EXTERN+UNDEF:
		return;
	}
	if (cursym.s.stype&EXTERN)
		cursym.s.stype = EXTERN+ABS;
}
/* readhdr -	Read in an a.out header, adjusting relocation offsets */
readhdr(pos)
long pos;
{
	register long st, sd;
	fseek(text, pos, 0);
	dread(&filhdr, sizeof filhdr, 1, text);
	if (filhdr.fmagic != FMAGIC)
		fatal(e5a, filename);
	st = (filhdr.tsize+1) & ~1;
	filhdr.tsize = st;
	cdrel = -st;
	sd = (filhdr.dsize+1) & ~1;
	cbrel = - (st + sd);
	filhdr.bsize = (filhdr.bsize+1) & ~1;
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
	for (i = 0; i < SYMLENGTH; i++)
	{
		if ((c = getc(text)) == EOF) fatal(e3, filename);
		else if ((csymbuf[i] = c) == 0)
		{
			if ((cursym.snlength = i) == 0) error(e18, filename);
			cursym.sname = csymbuf;
			return(sizeof(cursym.s) + i + 1);
		}
	}
	csymbuf[SYMLENGTH] = '\0';	/* make sure asciz */
	return(sizeof(cursym.s) + i);
}

/* error -	Print out error messages and give up if they are severe. */

/*VARARGS1*/
error(fmt, a1, a2, a3, a4, a5)
char *fmt;
{
	printf("ld68: ");
	printf(fmt, a1, a2, a3, a4, a5);
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
FILE *file;
{
	if (fread(pos, size, count, file) == size * count) return;
	if (feof(file)) fatal(e3, filename);
	if (ferror(file)) fatal(e4, filename);
}


/* dcopy -	Copy input to output, checking for errors */

dcopy(in, out, count)
FILE *in, *out;
long count;
{
	register int c;
	long n = count;
	if (n < 0) bletch("bad count to dcopy");
	while(n--)
	{
		if ((c = getc(in)) == EOF)
		{
			if (feof(in)) fatal(e3, filename);
			if (ferror(out)) fatal(e4, filename);
		}
		putc(c, out);
	}
}


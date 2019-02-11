/* 68000 DDT
 * Jim Lawson and Vaughan Pratt -  1981
 *
 */ 

#ifdef MC68000
#define NULL 0				/* from stdio.h */
#define BPTADR *(int(**)())0xb8		/* trap 14 address */
#define TRCADR *(int(**)())0x24		/* trace address */

extern char emt_getchar();

#else ifndef MC68000
#include <stdio.h>
#endif MC68000

#include "ddt.h"

extern struct cbuffr bfr1, bfr2;
extern struct cbuffr *cbfp;

extern short dasm();
extern ddtbpt(), ddttrct();

extern char legal;		/* if last instruction disassembled was */

extern struct sym *dasmsymbol();	/* lookup symbol given value */
extern struct sym *dasmsymbolic();	/* output symbol given value */

static struct bpstr
bp[BPMAX + 1] = { 0 };	/* breakpoint structures */

#define SSBP		0	/* plus one for single stepping */
				/*  over subroutine calls. */

#define BSRINST		0x6100	/* one flavour of subroutine call */
#define JSRINST		0x4E80	/* another flavour */
#define TRAPINST	0x4e40	/* a third flavour */

#define oddpc ((int)pc&1)

static struct bpstr *
cbptr = bp; 			/* current breakpoint or NULL */

static char ssflag = 0;		/* flag set non-zero if single stepping */
static char single = 0;		/* says to set trace bit on exit */
static long sscount = 1;	/* how many single steps */
static short bpno;		/* current bpt if any, else -1 */
short *ddtopc;			/* pc at breakpoint */
short ddtosr;			/* status register at breakpoint */
long ddtsvregs[16] = {0};	/* registers at time of breakpoint */
static short *quitpc;		/* exit pc */
static short quitsr;		/* exit status reg */
static long quitsp;		/* exit stack pointer */
static long smask;		/* string mask - masks chars read */
static long tmask;		/* temporary mask used in search */

static short iradix = DEFRADIX;	/* input radix */
static short oradix = DEFRADIX;	/* output radix */
static long mask = ~0;		/* search mask */
static char *lowlimit, *hilimit;/* search limits */

static char gotarg;		/* true if argument supplied on command */
static long comarg;		/* value of argument */
static char compfx;		/* command prefix */

static int dspbyte();
static int dspword();
static int dsplong();
static int dspsymb();
static int dspstrg();

static int (*dspdata[])() = {	/* array of pointers to int functions */
	dsplong,		/* default */
	dspbyte,
	dspbyte,
	dspword,
	dsplong,
	dspsymb,
	dspstrg	};

static int putbyte();
static int putword();
static int putlong();
static int putstrg();

static int (*depdata[])() = {
	putlong,		/* default deposit */
	putbyte,
	putbyte,
	putword,
	putlong,
	putword,
	putstrg		};

static long lgetbpc();
static long lgetwpc();
static long lgetlpc();
static long lgetspc();

static long (*getldata[])() = {
	lgetlpc,		/* default search mode */
	lgetbpc,
	lgetbpc,
	lgetwpc,
	lgetlpc,
	lgetwpc,
	lgetspc		};

symtabdef ddtusrsyms = {0, 0};		/* start,limit of user symbols */
static char symtype; 			/* type of last symbol found */

static char tomode = 0, tmptomode = 0, dtype = 0;	/* type-out mode */

static short escno;			/* number of escape chars typed */

static char *dot = (char *) 0x1000;	/* last location examined */
static char das = 'u';			/* address space */

static char *symterms = "+- |\r\n/=\\<>?";/* characters which delimit symbols */
static char *argterms = "\r\n*/=\\<>?";	/* ditto for arguments */
#define COMCHRS		"/qgpxbr=*t\\<>?m\n\r"

/*
 * fetch various flavours of data from memory, returning a long.
 */
static long
lgetbpc(pc) 
char *pc;
{

	return( getbpc(pc) ); 
}

static long
lgetwpc(pc)
char *pc;
{

	return getwpc(pc) ;
}

static long
lgetlpc(pc)
char *pc;
{

	return getlpc(pc) ;
}

static long
lgetspc(pc)
char *pc;
{

      switch ( smask) {
	case 0:
	case 0x7f7f7f7f:return oddpc?(getlpc(pc-1)<<8)|getbpc(pc+3):getlpc(pc);
	case 0x7f:	return getbpc(pc);
	case 0x7f7f:	return oddpc?(getbpc(pc)<<8) | getbpc(pc+1):getwpc(pc);
	case 0x7f7f7f:	return (oddpc? getlpc(pc-1): getlpc(pc)>>8) & 0xffffff;
      }
}

symtabdef ddtsymdef;

/* Special ddt symbols */
struct {struct sym a; char name[4];} ddtsyms[] = {
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[0]}, { '$','d','0',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[1]}, { '$','d','1',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[2]}, { '$','d','2',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[3]}, { '$','d','3',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[4]}, { '$','d','4',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[5]}, { '$','d','5',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[6]}, { '$','d','6',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[7]}, { '$','d','7',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[8]}, { '$','a','0',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[9]}, { '$','a','1',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[10]}, { '$','a','2',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[11]}, { '$','a','3',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[12]}, { '$','a','4',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[13]}, { '$','a','5',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[14]}, { '$','f','p',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[14]}, { '$','a','6',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[15]}, { '$','s','p',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtsvregs[15]}, { '$','a','7',0 } },
{ { LONGTYPE|DDTSYM, 3, (long) &ddtopc}, { '$','p','c',0 } },
{ { WORDTYPE|DDTSYM, 3, (long) &ddtosr}, { '$','s','r',0 } },
{ { POINTERTYPE|DDTSYM, 3, (long) &dot}, {'.',0,0,0 } },
{ { 0, 0, 0}, {0,0,0,0} }
};

/*
 * Output a string.
 */
static
putstring( sp )
register char *sp;
{
    while( *sp ) emt_putchar( *sp++ );
}

/*
 * Force a character to upper case.
 */
static char
forceupper(c)
char c;
{
    if( (c) >= 'a' && (c) <= 'z') c = c - 'a' + 'A';
    return(c);
}

/*
 * Convert a character to a format suitable for symbols.
 */
static char
macify(c)
char c;
{
#ifdef DM
    return( forceupper(c) );
#else
    return( c );
#endif
}

/*
 * Validate candidate for new radix.
 */
static short
setradix(value)
long value;
{
    if( value > 0 && value < 26L )	/* possible radix ? */
	return((short) value);
    else
	return(DEFRADIX);		/* return default */
}

/*
 * Convert a number to its ascii representation in the current output radix.
 */
void
numout(number)
unsigned long number;
{
register unsigned short c;

    c = number % oradix;
    if( number /= oradix ) numout( number );
    c &= 0xFF;
    c += (c > 9) ? ( 'A' - 10 ) : '0';
    dasmput(c);
}

/*
 * Print a number in the current output radix.
 */
static void
printnum(number)
long number;
{
    bfr1.pnt= 0;
    bfr1.col= 1;
    cbfp = &bfr1;
    numout( number );		/* output value of arg */
    dasmput('\0');
    putstring(bfr1.buf);
}

/*
 * Print address at pc in a suitable format.
 */
static void
printadrs( pc )
long pc;
{
symtabdef *table;
register struct sym *sp;

    if( das == 'd' )			/* in ddt's address space ? */
	table = &ddtsymdef;
    else
	table = USRSYMS;
    bfr1.pnt= 0;
    bfr1.col= 1;
    cbfp = &bfr1;
    dasmsymbolic( pc, table );
    dasmput('\0');
    putstring(bfr1.buf);
}

/*
 * Test character set membership.
 */
static short
oneof(c,string)
register char c, *string;
{
register char m;

    while(( m = *string++ ))
	if( c == m ) return(1);
    return(0);
}

/*
 * Check a character to see if it's a valid digit in the current radix.
 */
static short
isdig(c, d)
register char c;
short *d;
{
register short valid;

    *d = 0;
    c = forceupper(c);

    if( c < '0' ) valid = 0;	/* not a digit no how */
    else if( iradix <= 10 )
	if( c > ( '0' + iradix - 1 ) ) valid = 0;
	else 
	{
	    valid = 1;
	    *d = c - '0';
	}
    else if( c <= '9' )
	{
	    valid = 1;
	    *d = c - '0';
	}
	else if( c > ( 'A' + iradix -10 -1 ) ) valid = 0;
	    else
	    {
		valid = 1;
		*d = c - 'A' + 10;
	    }
    return(valid);
}

/*
 * Build a number and return the character that delimited it.
 */
static char
getnum(string, value)
char *string;
long *value;
{
char c;
short d;
register long n = 0;

    while( isdig((c = *string++), &d))	/* while we're eating digits...*/
    {
	n = n * iradix + d;
    }
    *value = n;
    return(c);
}

/*
 * Look up a string in the symbol table. Return a pointer to entry if found,
 * NULL if not.
 */
static struct sym*
findsym(string, table)
char *string;
symtabdef *table;
{
register struct sym *current;
    for( current = table->start; current < table->limit;
    	current = (struct sym *)((int)(current+1) + current->slength + ADJ))
    { register char *sym = string;
      register char *name = (char *)(current+1);
      register short i;

	for( i = MAXSYMLEN; i; i-- )
	{
	    if( *sym == '\0' )
		if( *name == ' ' || *name == '\0' )
		    return(current);	/* found it */
	    if( *sym++ != *name++) break;
	}
	if( i == 0 ) return( current );
    }
    return((struct sym *) NULL);
}

/*
 * Add a symbol to the symbol table. Returns a pointer to the new
 * symbol entry if successful, NULL otherwise.
 */
static struct sym*
addsym( string, value, table )
register char *string;
long value;
symtabdef *table;
{
register struct sym *sp = table->limit++;
register char *name = (char *)(sp+1);
register short i;

    for( i = MAXSYMLEN; i; i-- )
    {
	if( *string != '\0' )		/* end of string ? */
	    *name++ = *string++;		/* if not, copy characters */
	else
	    *name++ = '\0';		/* otherwise, spaces */
    }
    sp->svalue = value; 			/* set the value of the symbol */
    return( sp );
}

/*
 * Scan characters into a symbol, set the value of the symbol,
 * and return the character that delimited the symbol. Set gotarg to 1
 * if a symbol was successfully scanned.
 */
static char
getsym(symvalue)
register long *symvalue;
{
char c, symbol[40];
register char *sptr = symbol;
register struct sym *symadr;

/* insert characters into symbol until we hit an argument terminator */

    smask = 0;
    *symvalue = 0;
    while( !oneof( ( c = emt_getchar()), symterms))
	if (c == 127) {
		if (sptr > symbol) {
			sptr--;
			putstring("\b \b");
		}
	}
	else *sptr++ = macify(c);

    *sptr = '\0';

	if(( sptr - symbol ) == 0 ) return c; /* case of reading nothing */
	das = 'u';			/* assume user's address space */
	gotarg = 1;			/* we have an argument */

/* if starts with '"' it must be a string - get last 4 chars */
	if ( symbol[0] == '"') {
		char *sptr = symbol+1;
		*symvalue = 0;
		while ( sptr[0] && (sptr[0] != '"' || sptr[1] == '"' )) {
			*symvalue = (*symvalue<<8) | sptr[0];
			smask = (smask<<8) | 0x7f;
			if (sptr[0] == '"') sptr++;
			sptr++;
		}
		return c;
	}

/* assume what we have is a symbol and look for it in ddt's symbol table */

	if((symadr = findsym(symbol, &ddtsymdef)))
		das = 'd';		/* ddt's address space */

/* if we don't find it there, look for it in the user's symbol table */

	else symadr = findsym( symbol, USRSYMS );

	if( symadr ) {	      /* if either returned an address, we found it. */
	    symtype = symadr->stype;	/* remember symbol type */
	    if(( symtype & DDTSYM ) && ( symtype & POINTERTYPE ))
	    {
		*symvalue = *(long *) symadr->svalue;
		das = 'u';		/* really user address space */
	    }
	    else *symvalue = symadr->svalue;	/* return its value */
	}
	else {				/* assume it's a numeric constant */
	    symtype = 0;		/* type is unknown */
	    if( getnum(symbol, symvalue) != '\0') {
		c = BADARG;
		gotarg = 0;
		*symvalue = 0;
	    }
	}

    return c;
}

/*
 * Ascertain the correct type-out mode for the current display.
 * If the user has specified a type-out mode (or symbol type) use
 * that, else, if the symbol type is known, use that, otherwise,
 * carry on using the current mode.
 */
static
settomode( pc )
char *pc;
{
symtabdef *table;
register struct sym *sp;

    if( das == 'd' )			/* ddt symbol ? */
	table = &ddtsymdef;
    else
	table = USRSYMS;
    sp = dasmsymbol( pc, table );	/* find nearest symbol */
    symtype = sp? sp->stype: 0;
    if( tmptomode )			/* over-riding default mode ? */
	dtype = tmptomode;
    else if( tomode )			/* user-specified type ? */
	dtype = tomode;			/* use that */
    else
	dtype = symtype;
    dtype &= TYPEFIELDMASK;
}

/*
 * Convert single character type specification into appropriate type-out
 * mode.
 */
static short
gettomode( c )
char c;
{
short totype;
    switch( c )
    {
	case 'c':   totype = CHARTYPE;
		    break;

	case 'h':   totype = BYTETYPE;
		    break;

	case 'w':   totype = WORDTYPE;
		    break;

	case 'l':   totype = LONGTYPE;
		    break;

	case 'i':   totype = INSTTYPE;
		    break;

	case 's':   totype = STRTYPE;
		    break;

	default:    totype = 0;
		    break;
    }
    return( totype );
}

/*
 * Make sure pc contains a valid word address
 */
static char *
wordadr( pc )
register long pc;
{
    return ((char *) ( pc & ~1 ));	/* better be even */
}

/*
 * Here to display data
 */
static int
display( type, adrs )
char *adrs;
short type;
{
    return( (*dspdata[type])(adrs) );
}

/*
 * Here to deposit data
 */
static int
deposit( type, adrs, data )
short type;
char *adrs;
long data;
{
    return( (*depdata[type])(adrs, data) );
}

/*
 * Here to increment pc.
 */
static char *
inc_pc( pc, inc )
register char *pc;
register int inc;
{
    return( (char *) pc + inc );
}

/*
 * Function to decrement pc. Returns pc - inc.
 */
static char *
dec_pc( pc, dec )
register char *pc;
register int dec;
{
register int nwords = 0, i;
register short *pos = (short *) wordadr( pc ) - 6;

    if( dtype == INSTTYPE )
    {
	for( i = 5; i > 0; i--)
	{
	    if (getbpc(++pos) != -1) {
		nwords = dasm(pos);	/* attempt to disassemble */
	    	if( legal && ( nwords == i ) ) return( (char *) pos );
	    }
	}
	if (getbpc(wordadr(pc)) == -1) return wordadr(pos);
	else return wordadr(pos)-1;
    }
    if (dtype == STRTYPE)
    {
	while (getbpc(--pc) == 0);
	while (getbpc(--pc) > 0);
	if (getbpc(pc) == -1) pc++;
	return pc;
    }
    return((char *) pc - dec );
}

/*
 * Here to get data from memory for search comparision
 */
static long
getsearchval( type, pc )
char *pc;
short type;
{
    return( (*getldata[type])( pc ) );
}

/* Commands consist of an argument terminated by one or more argument
 * terminators, followed by a single character command.  Arguments may be
 * numeric constants, symbols or register specifications.
 */
static char
getarg()
{
long symvalue;
char c, nxdel;

    gotarg  = 0;
    comarg = 0;

    c = getsym(&comarg);		/* eat a symbol */
    while(!oneof(c, argterms))
    {
	nxdel = getsym(&symvalue);	/* eat another symbol */
	switch(c)
	{
	    case '|':	comarg |= symvalue; break;
	    case '+':	comarg += symvalue; break;
	    case '-':	comarg -= symvalue; break;
	    default:	comarg = symvalue; break;
	}
	c = nxdel;
    }
    return(c);
}

static char
getcom()
{
char c;

    escno = 0;
    c = getarg();		/* get argument */
    while( c == ESCCHR )
    {
	escno++;		/* count escapes */
	emt_putchar(0);		/* render escape harmless to tty */
	emt_putchar('$');	/* and echo dollar */
	c = emt_getchar();
    }
    return(c);
}

/*
 * Interpret the command argument (if there is one) as a pc. 
 */
static short
setpc(pcptr)
char **pcptr;
{
    if( gotarg )			/* was an argument supplied ? */
    {
	if( !comarg || ( comarg & 1 ) )	/* better be non-zero and even */
	{
	    return(0);			/* otherwise, don't do anything */
	}
	*pcptr = (char *) comarg;	/* set pc */
    }
    return(1);
}

/*
 * Function to display data at pc in symbolic format. Returns number
 * of bytes displayed.
 */
static int
dspsymb(pc)
char *pc;
{
int nbytes;

    pc = wordadr( pc );			/* legal word address */
    nbytes = dasm( pc ) * 2;		/* disassemble and return size */
    putstring(bfr2.buf);		/* print hex pc and contents */
    putstring(bfr1.buf);		/* print symbolic " */
    return( nbytes );
}

/*
 * Function to display pc and contents as a single byte. Returns number
 * of bytes displayed (i.e. 1)
 */
static int
dspbyte(pc)
char *pc;
{
    printadrs( pc );		/* type out pc value */
    emt_putchar(' ');
    if( dtype == CHARTYPE) {
	emt_putchar('\'');
	if (getbpc(pc) == '\'') emt_putchar('\\');
	nicechar( getbpc( pc ) );
	emt_putchar('\'');
    }
    else printnum( (long) ( getbpc( pc ) & 0xFF ) );
    return( 1 );
}

/*
 * Function to deposit byte of data at pc.
 */
static int
putbyte( pc, longdata)
char *pc;
long longdata;
{
    putbpc(pc, longdata);
    return( 1 );
}

/* Function to display pc and contents as a single word. Returns number of
 * bytes displayed (i.e. 2).
 */
static int
dspword(pc)
char *pc;
{
    pc = wordadr( pc );			/* valid word address */
    printadrs(pc);			/* print pc in hex */
    emt_putchar(' ');
    printnum( (long) ( getwpc(pc) & 0xFFFF ) );	/* print word contents */
    return( 2 );			/* always display 2 bytes */
}

/*
 * Function to deposit word of data at pc.
 */
static int
putword( pc, longdata)
char *pc;
long longdata;
{
    putwpc(pc, longdata);
    return( 2 );
}

/*
 * Function to display pc and contents as a long. Returns number of bytes
 * displayed (i.e. 4)
 */
static int
dsplong( pc )
char *pc;
{
    pc = wordadr( pc ); 		/* legal word address */
    printadrs( pc );
    emt_putchar(' ');
    printnum( getlpc( pc ) );
    return( 4 );			/* always display 4 bytes */
}

/*
 * Function to deposit long at pc.
 */
static int
putlong( pc, longdata)
long *pc;
long longdata;
{
    putlpc(pc, longdata);
    return ( 4 );
}

static
nicechar(c)
char c;
{
	if (' ' <= c && c < 127) emt_putchar(c);
	else switch(c) {
		case '\b': putstring("\\b"); break;
		case '\t': putstring("\\t"); break;
		case '\r': putstring("\\r"); break;
		case '\n': putstring("\\n"); break;
		case '\\': putstring("\\\\"); break;
		case 127:  putstring("^?"); break;
		default:   if (0 <= c && c < ' ') {
				emt_putchar('^');
				emt_putchar(c+64);
			   }
			   else {
				   emt_putchar('\\'); 
				   emt_putchar('0'+((c>>6)&3));
				   emt_putchar('0'+((c>>3)&7));
				   emt_putchar('0'+(c&7)); break;
			   }
		}
}

/*
 * display string pointed to by pc
 */
static int
dspstrg( pc )
char *pc;
{
   int c, len=0;
   printadrs( pc );
   putstring(" \"");
   while ((c = getbpc(pc++)) > 0) {
	if (c == '"') emt_putchar('\\');
	nicechar(c);
	len++;
   }
   emt_putchar('"');
   return len+1;
}

/*
 * deposit string starting at pc
 */
static int
putstrg(pc, s)
char *pc, *s;
{
   int len = 0;
   while (*s) {
	putbpc(pc++, *s++);
	len++;
   }
   putbpc(pc++, '\0');
   return len;
}

#ifdef MC68000
/* Breakpoint routines.
 *
 * Breakpoint 0 is reserved for single stepping over subroutine calls.
 */

#define ALLBPLOOP(i, p)		for( i = 0, p = &bp[0]; i <= BPMAX; i++, p++ )
#define USERBPLOOP( i, p)	for( i = 1, p = &bp[1]; i <= BPMAX; i++, p++ )

/* Here to remove breakpoints, i.e. stick original instructions back
 * in the calling program. In addition, it returns the one-origin index
 * breakpoint id.
 */
static short
rmovebps()
{
register struct bpstr *bpptr;
register short i, bpno = -1;

    ALLBPLOOP( i, bpptr )
    {
	if( bpptr->pc != NULL )		/* this breakpoint in use ? */
	{
	    if( *bpptr->pc == BPINST )	/* was it actually set ? */
	    {
		if( ddtopc == bpptr->pc )	/* find the breakpoint ? */
		    bpno = i;		/* save breakpoint index */
		*bpptr->pc = bpptr->oldinst;/* replace original instruction */
	    }
	}
    }
    return( bpno );			/* indicate which breakpoint it was */
}

/* Here to plant breakpoints. Returns the number of breakpoints set.
 */
static short
plantbps()
{
register struct bpstr *bpptr;
register short i, nbp = 0;

    ALLBPLOOP( i, bpptr )
    {
	if( bpptr->pc != NULL )		/* if breakpoint pc is non-zero, */
	{
	    nbp++;			/* one more bp set. */
	    if( *bpptr->pc != BPINST )	/* forget this if already there */
	    {
		bpptr->oldinst = *bpptr->pc;/* save old instruction */
		*bpptr->pc = BPINST;	/* set breakpoint instruction */
	    }
	}
    }
    return( nbp );
}

/* Here to clear breakpoints, just set breakpoint pc to 0. By this time
 * the original instructions should already be back in the calling program.
 */
static void
clearbps()
{
register struct bpstr *bpptr;
register short i;

    ALLBPLOOP( i, bpptr )
	bpptr->pc = NULL;		/* no longer in use */
}

/* Set a breakpoint. */
static
setabp( adrs, bpno )
register short *adrs;
register char bpno;
{
register short i;
register struct bpstr *bpptr, *fbp = NULL;

    USERBPLOOP( i, bpptr )		/* go through the breakpoint array, */
    {					/* removing any breakpoints already */
	if( bpptr->pc == adrs ) bpptr->pc = NULL; /* set at this location, */
	if( ( fbp == NULL ) && ( bpptr->pc == NULL ) )   /* and */
	    fbp = bpptr;		/* remember likely candidates for */
    }					/* new breakpoint. */
    if( bpno )				/* if user supplied specific bp no. */
	fbp = &bp[bpno];		/* use it. */
    if( fbp == NULL ) 			/* do we know where to put this bp ?*/
	putstring( "no bp\n" );		/* complain if not...*/
    else
	fbp->pc = adrs;
}

/* Clear a breakpoint.
 */
static
clearabp( bpno )
register char bpno;
{
    if( bpno )				/* specific bp to clear ? */
	bp[bpno].pc = NULL;
    else
	clearbps();			/* remove all breakpoints */
}

/* Print breakpoints.
 */
static
printbps()
{
register struct bpstr *bpptr;
register short i;
char *bppos = "B0 @ ";

    emt_putchar('\n');
    USERBPLOOP( i, bpptr )
    {
	if( bpptr->pc )
	{
	    bppos[1] = i + '0';
	    putstring(bppos);
	    printadrs( bpptr->pc );
	    emt_putchar('\n');
	}
    }
}

#endif MC68000

/* Major command loop. Process commands until we get a "go" or "continue".
 */
static
comloop()
{
char c, go = 0, lopen = 0;
short nbytes, inc;
char *adrs;
long temp;
long test, searchvalue;
char searchmode;

    emt_putchar('\n');
    if ((ssflag && sscount>0 && (!cbptr || cbptr->count>0)) ||
	(!ssflag && cbptr && cbptr->count>0))
		return;
    ssflag = 0;				/* out of single step mode */
    while (!go)
    {
	if( !lopen ) putstring(".");
	compfx = 0;			/* no command prefix */
	c = getcom();			/* get argument and command */
	if( !oneof( c, COMCHRS ) )	/* if this isn't a command, */
	{
	    compfx = c;			/* assume it's a prefix and */
	    c = emt_getchar();		/* get another character. */
	}
	switch(c)			/* dispatch on delimiter */
	{
	    badcom:
	    default:
	    case BADARG:
			putstring("?");
			break;

	    case '/':
	    case '\\':	if( lopen )
			{
			    if( gotarg ) nbytes = deposit( dtype, dot, comarg );
			    dot = ( c == '/' ) ? inc_pc( dot, nbytes )
					       : dec_pc( dot, nbytes );
			}
			else
			{
			    if( gotarg ) dot = (char *) comarg;
			}
			settomode( dot );
			if (dtype == STRTYPE)
				while (!getbpc(dot)) dot++;
			emt_putchar('\n');
			nbytes = display( dtype, dot );
			emt_putchar(' ');
			lopen = 1;	/* location is open */
			break;
			
	    case '\r':
	    case '\n':	if( lopen )
			{
			    if( gotarg ) deposit( dtype, dot, comarg );
			    lopen = 0;
			}
			tmptomode = 0;		/* clear default type-out */
			break;

	    case 'm':	if( gotarg ) mask = comarg;
			break;

	    case '<':	if( gotarg ) lowlimit = (char *) comarg;
			c = getarg();		/* get next argument */
			if( c == '>' )
			{
			/* no break */
		
	    case '>':	if( gotarg ) hilimit = (char *) comarg;
			c = getarg();	/* get next argument */
			}
			if( c != '?' )
			    goto badcom;
			/* no break */

	    case '?':	if( gotarg ) searchvalue = comarg;
			settomode( dot );
			searchmode = smask? STRTYPE: dtype;
			tmask = smask? smask: mask;
			inc = ( searchmode == CHARTYPE || 
				searchmode == BYTETYPE ||
				searchmode == STRTYPE)?    1: 2;
			for( adrs = lowlimit; adrs < hilimit; adrs += inc)
			{
			    test = getsearchval( searchmode, adrs);
			    if( ( test & tmask ) == ( searchvalue & tmask ) ) {
				emt_putchar('\n');
				display( searchmode, adrs );
			    }
			}
			break;
#ifdef MC68000
	    case 'g':	if( setpc( &ddtopc) ) 	/* valid pc ? */
			    go = 1;
			else
			    goto badcom;
			break;

	    case 'p':	if( cbptr) 		/* inside a break point ? */
			    cbptr->count = gotarg? (short) comarg : 1;
			go = 1;
			break;

	    case 'x':	sscount = 1;
			if (gotarg) sscount = comarg;
			ssflag = escno;	/* do single step */
			go = 1;
			break;

	    case 'b':	if( gotarg )		/* get any argument ? */
			{

/* if we got a prefix, this is a specific breakpoint specification */

			    if( compfx )
			    {
				compfx -= '0';
				if( compfx <= 0 || compfx > BPMAX )
				    goto badcom;
			    }
			    if( comarg )	/* non-zero ? */
			    {
				if( !setpc( &comarg ) ) /* legal pc address */
				    goto badcom;
				setabp( comarg, compfx );
				if ( comarg == (long)ddtopc ) bpno = 1; /* > 0 */
			    }
			    else {
				clearabp( compfx );
				if ( !compfx || compfx == bpno) 
					bpno = -1;
			    }
			}
			else
			    printbps();
			break;

#endif MC68000
	    case 'r':	temp = setradix( comarg );
			if( compfx == 'i' ) iradix = temp;
			else if( compfx == 'o' ) oradix = temp;
			else goto badcom;
			break;

	    case '=':	printnum( comarg );
			break;

	    case 't':	if( escno > 1 ) {
			    	tomode = gettomode( compfx );
			    	tmptomode = 0;
			}
			else tmptomode = gettomode( compfx );
			break;

	    case '':
			break;
#ifndef MC68000
	    case 'q':	ddtopc = quitpc;		/* reset pc */
			ddtosr = quitsr;		/* status register */
			ddtsvregs[15] = quitsp;	/* and stack */
			go = 1;
			break;
#endif
	}
	if (!lopen) emt_putchar('\n');
    }
}

#ifdef MC68000
/* Here on a trace trap.
 */
ddttrace()
{
    if( ssflag == 1 )			/* are we single stepping */
    {					/*  everything ? */
	ddtbrk();
    }
    else				/* this is breakpoint cleanup */
	plantbps();			/* or subroutine single step */
}

#endif MC68000
	
/*
 * Onceonly code to be executed on initial startup.
 */
char ddtfirst = 1;

#ifdef MC68000
extern struct {short skip; struct sym *symstart;} _start; /* crtsun structure*/
#endif

/* Initialize slength member of symbol table entry */
static setlen(sp)
struct sym *sp;
{

	return ( sp->slength = strlen(sp+1) );
}

static void 
onceonly(x)
{
register struct sym *sp;

    if( ddtfirst )
    {
	ddtfirst = 0;
	ddtsymdef.start = (struct sym *)ddtsyms;
	for( sp = (struct sym *)ddtsyms; 
	     *(char*)(sp+1) != '\0';
	     sp = (struct sym *)((int)(sp+1) + setlen(sp) + ADJ));
	ddtsymdef.limit = sp;
	if (!(USRSYMS->start)) {
		USRSYMS->start = _start.symstart;
		USRSYMS->limit = (struct sym *)((int)(_start.symstart)
					     + ((int*)(_start.symstart))[-1]
					     - 18);
	}
	for (sp = USRSYMS->start; 
	     sp < USRSYMS->limit;
	     sp = (struct sym *)((int)(sp+1) + setlen(sp) + ADJ))
		switch (sp->stype & 7) {
			case TEXT:	sp->stype = INSTTYPE; break;
			case BSS:
			case DATA:	sp->stype = LONGTYPE; break;
			default:	sp->stype = 0; break;
		}

/* memorize initial entry conditions */

	quitpc = ddtopc;			/* save original pc */
	quitsr = ddtosr;			/* save status reg */
	quitsp = ddtsvregs[15];			/* save stack */

#ifdef MC68000
	BPTADR = ddtbpt;			/* set trap vector */
	TRCADR = ddttrct;			/* set trace vector */
#endif
    }
}

/* Here from the breakpoint trap instruction. Figure out which breakpoint
   it is and print the appropriate message.
 */
ddtbrk()
{

char *bpstring = "B0>  ";
	onceonly();			/* do once only code */
#ifdef MC68000
	ddtosr &= 0x7fff;			/* clear trace bit in sr */
    	bpno = rmovebps();		/* remove breakpoints */
	if( bpno == SSBP )		/* if this was the subroutine ss, */
	    bp[SSBP].pc = NULL;		/* its gone now. */
	bpstring[1] = bpno + '0';	/* indicate which bp or ss */
        putstring(bpstring);		/* output breakpoint header */
	while (!dasm(ddtopc)) ddtopc--;	/* back up to legal instruction */
	putstring(bfr2.buf);		/* and display it */
	putstring(bfr1.buf);
	if (ssflag) sscount--;		/* count down single step */
	if( bpno > SSBP ) {		/* if breakpoint, */
	    cbptr = &bp[bpno];		/* remember appropriate pointer */
	    cbptr->count--;		/* count down the breakpoint counter */
	}
	else
	    cbptr = NULL;
	dot = (char *) ddtopc;		/* dot defaults to here */
#endif MC68000
	comloop();			/* process commands */

/* we are about to return to the calling program. set breakpoints or
 * turn on tracing.
 */

#ifdef MC68000

    if(ssflag) {
	if (escno > 1 )		/* should we worry about subroutines? */
	    if( ( ( *ddtopc & 0xFF00 ) == BSRINST ) ||
		( ( *ddtopc & 0xFFC0 ) == JSRINST ) ||
		( ( *ddtopc & 0xFFF0 ) == TRAPINST ) ) {
			bp[SSBP].pc = ddtopc + dasm( ddtopc );/* set bp at return */
	    		ssflag = escno;
            }
        else ssflag = 1;		/* same as ordinary single step */
    }

    if( ssflag || bpno > 0 )		/* if single-stepping, */
    {					/*   or it's time for bp cleanup, */
	ddtosr |= 0x8000;			/* turn on the trace bit */
    }
    else				/* otherwise, */
    {
	plantbps();			/*   plant breakpoints */
    }
#endif MC68000
}

#ifndef MC68000

#include <signal.h>
#include <sgtty.h>

#define R	0		/* read-only mode */
#define RW	2		/* open for read/write */
#define FBLK	512		/* 512 byte reads */
#define MAXSYMLEN	10	/* must agree with ddt and dl68 */

struct sgttyb ttystate, *ttystatep = &ttystate;
short oflags;			/* place to remember the original tty flags */
int cleanup();
int (*cleanupptr)() = cleanup;	/* pointer to cleanup function */

struct bhdr filhdr;

unsigned char fbfr[FBLK] = { 0 };
int ifile;
unsigned char *bfrendpc, *bfrbegpc;
char bfrchnge;

unsigned char *origin = (unsigned char *)0x1000;

extern int open();
extern int read();

/* fetch a buffer that contains the byte pointed to by pc */
int getbfr( pc )
unsigned char *pc;
{
int nchars;
long fpc;

    if (pc < origin) {
	putstring("pc too small");
	return -1;
    }
    fpc = pc - origin + sizeof(filhdr);
    lseek( ifile, fpc, 0);	/* position the file */
    bfrendpc = bfrbegpc = pc;
    nchars = read( ifile, fbfr, FBLK);
    if( nchars > 0 )
	bfrendpc += nchars;
    else
    {
	putstring("pc too large");
	return -1;
    }
    return( nchars );
}

/* see if location desired is in the buffer */
int inbfr( pc )
unsigned char *pc;
{
    if( bfrbegpc <= pc && pc <= bfrendpc ) return(1);
    else return(0);
}

/* fetch the byte at pc */
getbpc(pc)
unsigned char *pc;
{
    if( das == 'd' )		/* fetch from ddt's address space ? */
    {
	return( (int)*pc );
    }
    if( !inbfr( pc ) )
	if (getbfr( pc ) == -1) return -1;
    return( (int)fbfr[pc - bfrbegpc] );
}

/*
 * Write the byte at pc.
 */
void putbpc(pc, data )
unsigned char data;
unsigned char *pc;
{
    if( das == 'd' )
    {
	*pc = data;

    }
    else
    {
	if( !inbfr( pc ) )
	    getbfr( pc );
	fbfr[pc - bfrbegpc] = data;
	bfrchnge = 1;
    }
}
/* fetch the word at pc */
short getwpc(pc)
char *pc;
{
short word;
    if( das == 'd' )			/* fetch from ddt's address space ? */
    {
	word = *(short *) pc;
    }
    else
    {
	word = getbpc(pc) << 8;		/* get byte */
	word |= getbpc(pc+1) & 0xFF;
    }
    return( word );
}

/*
 * Write the word at pc
 */
void putwpc( pc, data )
char *pc;
short data;
{
    if( das == 'd' )
    {
	*(short *)pc = data;
    }
    else
    {
	putbpc( pc, (char) ( data >> 8 ) );
	putbpc( pc + 1, (char) ( data & 0xFF ) );
    }
}

/* fetch a long at pc */
long getlpc(pc)
char *pc;
{
long lword;
    if( das == 'd' )
    {
	lword = *(long *)pc;
    }
    else
    {
	lword = getwpc(pc) << 16;
	lword |= getwpc(pc+2) & 0xFFFF;
    }
    return( lword );
}

/*
 * Write the long at pc.
 */
void putlpc( pc, data )
char *pc;
long data;
{
    if( das == 'd' )
    {
	*(long *)pc = data;
    }
    else
    {
	putwpc( pc, (short) ( data >> 16 ) );
	putwpc( pc + 2, (short) ( data &0xFFFF ) );
    }
}

reverse(lwrd) unsigned lwrd;
 {return((lwrd>>24)	     |
	 (lwrd>>8 & 0xff00)  |
	 (lwrd<<8 & 0xff0000)|
	 (lwrd<<24)
	);
 }

readsyms(filename)
char *filename;
{
FILE *sfile;
struct sym s;
int symno, chrno;
char c;
struct sym *sp;

    if( ( sfile = fopen(filename, "r", sfile)) == NULL )
    {
	fprintf( stderr, "Can't open symbol file %s\n", filename);
	exit(2);
    }

    fseek(sfile, SYMPOS, 0);

    sp = ddtusrsyms.start = (struct sym *) malloc(filhdr.ssize);
    ddtusrsyms.limit = (struct sym *)((int)sp + filhdr.ssize);
    fread(sp,filhdr.ssize,1,sfile);		/* Get symbol table */
    fclose( sfile );				/* close the symbol file */
}

/*
 * reset the tty state to what it was originally.
 */
void resettty()
{
    ttystate.sg_flags = oflags;	/* restore original flags */
    stty( 0, ttystatep);	/* restore original tty state */
}

/* Here on a signal interrupt. reset the tty state and exit */
int cleanup(signo)
int signo;
{
    resettty();
    exit(4);
}

main(argc, argv)
int argc;
char *argv[];
{
int nchrs;

    if( argc != 2 )
    {
	fprintf( stderr, "usage: %s filename\n", argv[0]);
	cleanup();
    }
    if( ( ifile = open(argv[1], R ) ) == -1 )
    {
	fprintf( stderr, "Can't open %s\n", argv[1]);
	cleanup();
    }
    nchrs = read( ifile, &filhdr, sizeof(filhdr));
    if( nchrs <= 0 )
    {
	fprintf( stderr, "Unexpected eof or error on %s\n", argv[1]);
	cleanup();
    }
    if( filhdr.fmagic != FMAGIC )
    {
	fprintf( stderr, "%s doesn't look like a .out file \n", argv[1] );
	cleanup();
    }
    printf("text size: %ld\n", filhdr.tsize);
    printf("data size: %ld\n", filhdr.dsize);
    printf("bss size: %ld\n", filhdr.bsize);
    printf("symbol table size: %ld\n", filhdr.ssize);
    printf("text relocation size: %ld\n", filhdr.rtsize);
    printf("data relocation size: %ld\n", filhdr.rdsize);
    printf("entry point: 0x%lx\n", filhdr.entry);
    origin = (unsigned char *)filhdr.entry;
    if(filhdr.ssize > 0 )
	readsyms(argv[1]);
    else
	ddtusrsyms.start = ddtusrsyms.limit = 0;

/* now prepare for cbreak'ing */

    if( isatty(0) )			/* if we are connected to a tty */
    {
    int sig;

	gtty( 0, ttystatep);		/* get current tty state */
	oflags = ttystate.sg_flags;	/* save old flags */
	for( sig = 1; sig <= NSIG; sig++)
	    signal(sig, cleanup);	/* arrange to clean-up before exit */
	ttystate.sg_flags |= CBREAK;	/* turn on CBREAK */
	stty( 0, ttystatep);
    }
    ddt();
    resettty();
    putstring( "\n" );
}

#endif

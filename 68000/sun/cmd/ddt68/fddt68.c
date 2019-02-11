#include "ddt.h"
#include <stdio.h>
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

extern char das;		/* address space 'u' = user, 'd' = ddt */

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

    sp = usrsyms.start = (struct sym *) malloc(filhdr.ssize);
    usrsyms.limit = (struct sym *)((int)sp + filhdr.ssize);
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
	usrsyms.start = usrsyms.limit = 0;

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

# include <stdio.h>
# include <signal.h>

# include "mfile1"

extern int usedregs;	/* bit == 1 if reg was used in subroutine */
extern char *rnames[];
int proflag;
int strftn = 0;	/* is the current function one which returns a value */
FILE *tmpfile;
FILE *outfile = stdout;

branch( n ){
	/* output a branch to label n */
	/* exception is an ordinary function branching to retlab: then, return */
	if( n == retlab && !strftn ) printf( "	bra	.L%d\n", retlab );
	else printf( "	bra	.L%d\n", n );
	}

int lastloc = PROG;

defalign(n) {
	/* cause the alignment to become a multiple of n */
	n /= SZCHAR;
	if( lastloc != PROG && n > 1 ) printf( "	.even\n" );
	}

locctr( l ){
	register temp;
	/* l is PROG, ADATA, DATA, STRNG, ISTRNG, or STAB */

	if( l == lastloc ) return(l);
	temp = lastloc;
	lastloc = l;
	switch( l ){

	case PROG:
		outfile = stdout;
		printf( "	.text\n" );
		break;

	case DATA:
	case ADATA:
		outfile = stdout;
		if( temp != DATA && temp != ADATA )
			printf( "	.data\n" );
		break;

	case STRNG:
	case ISTRNG:
		outfile = tmpfile;
		break;

	case STAB:
		cerror( "locctr: STAB unused" );
		break;

	default:
		cerror( "illegal location counter" );
		}

	return( temp );
	}

deflab( n ){
	/* output something to define the current position as label n */
	fprintf( outfile, ".L%d:\n", n );
	}

int crslab = 10;

getlab(){
	/* return a number usable for a label */
	return( ++crslab );
	}

efcode(){
	/* code for the end of a function */

	if( strftn ){  /* copy output (in r0) to caller */
		register struct symtab *p;
		register int stlab;
		register int i;
		int size;

		p = &stab[curftn];

		deflab( retlab );
		retlab = getlab();

		stlab = getlab();
		printf( "	movl	d0,a0\n" );
		printf( "	movl	#.L%d,a1\n" , stlab );
		size = tsize( DECREF(p->stype), p->dimoff, p->sizoff ) / SZCHAR;
		while( size ){ /* simple load/store loop */
		  i = (size > 2) ? 4 : 2;
		  printf("	mov%c	a0@+,a1@+\n", i==2 ? 'w' : 'l');
		  size -= i;
		}
		printf( "	movl	#.L%d,d0\n", stlab );
		printf( "	.bss\n	.even\n.L%d:	.=.+%d.\n	.text\n", stlab, size );
		/* turn off strftn flag, so return sequence will be generated */
		strftn = 0;
		}
	branch( retlab );
	p2bend();
	}

bfcode( a, n ) int a[]; {
	/* code for the beginning of a function; a is an array of
		indices in stab for the arguments; n is the number */
	register i;
	register temp;
	register struct symtab *p;
	int off;
	char type;

	locctr( PROG );
	p = &stab[curftn];
	defnam( p );
	temp = p->stype;
	temp = DECREF(temp);
	strftn = (temp==STRTY) || (temp==UNIONTY);

	retlab = getlab();
	if( proflag ){
		int plab;
		plab = getlab();
		printf( "	movl	#.L%d,a0\n", plab );
		printf( "	jbsr	mcount\n" );
		printf( "	.data\n.L%d:	.long 0\n	.text\n", plab );
		}

	/* routine prolog */

	printf( "	link	a6,#-_F%d\n", ftnno );
	printf( "	moveml	#_S%d,a6@(-_F%d)\n", ftnno, ftnno );
	usedregs = 0;

	off = ARGINIT;

	for( i=0; i<n; ++i ){
		p = &stab[a[i]];
		if( p->sclass == REGISTER ){
			temp = p->offset;  /* save register number */
			p->sclass = PARAM;  /* forget that it is a register */
			p->offset = NOOFFSET;
			oalloc( p, &off );
			if (p->stype==CHAR || p->stype==UCHAR) type = 'b';
			else if (p->stype==SHORT || p->stype==USHORT) type = 'w';
			else type = 'l';
			printf( "	mov%c	a6@(%d),%s\n", type, p->offset/SZCHAR,
			  rnames[temp] );
			usedregs |= 1<<temp;
			p->offset = temp;  /* remember register number */
			p->sclass = REGISTER;   /* remember that it is a register */
			}
		else {
			if( oalloc( p, &off ) ) cerror( "bad argument" );
			}

		}
	printf("| A%d = %d\n", ftnno, off/SZCHAR);
	}

bccode(){ /* called just before the first executable statment */
		/* by now, the automatics and register variables are allocated */
	SETOFF( autooff, SZINT );
	/* set aside store area offset */
	p2bbeg( autooff, regvar );
	}

ejobcode( flag ){
	/* called just before final exit */
	/* flag is 1 if errors, 0 if none */
	}

aobeg(){
	/* called before removing automatics from stab */
	}

aocode(p) struct symtab *p; {
	/* called when automatic p removed from stab */
	}

aoend(){
	/* called after removing all automatics from stab */
	}

defnam( p ) register struct symtab *p; {
	/* define the current location as the name p->sname */

	if( p->sclass == EXTDEF ){
		printf( "	.globl	%s\n", exname( p->sname ) );
		}
	if( p->sclass == STATIC && p->slevel>1 ) deflab( p->offset );
	else printf( "%s:\n", exname( p->sname ) );

	}

bycode( t, i ){
	/* put byte i+1 in a string */

	i &= 07;
	if( t < 0 ){ /* end of the string */
		if( i != 0 ) fprintf( outfile, "\n" );
		}

	else { /* stash byte t into string */
		if( i == 0 ) fprintf( outfile, "	.byte	" );
		else fprintf( outfile, "," );
		fprintf( outfile, "%d", t );
		if( i == 07 ) fprintf( outfile, "\n" );
		}
	}

zecode( n ){
	/* n integer words of zeros */
	OFFSZ temp;
	register i;

	if( n <= 0 ) return;
	printf("	.zerol	%d\n", n );
	temp = n;
	inoff += temp*SZINT;
	}

fldal( t ) unsigned t; { /* return the alignment of field of type t */
	uerror( "illegal field type" );
	return( ALINT );
	}

fldty( p ) struct symtab *p; { /* fix up type of field p */
	;
	}

where(c){ /* print location of error  */
	/* c is either 'u', 'c', or 'w' */
	fprintf( stderr, "%s, line %d: ", ftitle, lineno );
	}

char *tmpname = "/tmp/pcXXXXXX";

main( argc, argv ) char *argv[]; {
	int dexit();
	register int c;
	register int i;
	int r;

	for( i=1; i<argc; ++i )
		if( argv[i][0] == '-' && argv[i][1] == 'X' && argv[i][2] == 'p' ) {
			proflag = 1;
			}

	mktemp(tmpname);
	if(signal( SIGHUP, SIG_IGN) != SIG_IGN) signal(SIGHUP, dexit);
	if(signal( SIGINT, SIG_IGN) != SIG_IGN) signal(SIGINT, dexit);
	if(signal( SIGTERM, SIG_IGN) != SIG_IGN) signal(SIGTERM, dexit);
	tmpfile = fopen( tmpname, "w" );
	if(tmpfile == NULL) cerror( "Cannot open temp file" );

	r = mainp1( argc, argv );

	tmpfile = freopen( tmpname, "r", tmpfile );
	if( tmpfile != NULL )
		while((c=getc(tmpfile)) != EOF )
			putchar(c);
	else cerror( "Lost temp file" );
	unlink(tmpname);
	return( r );
	}

dexit( v ) {
	unlink(tmpname);
	exit(1);
	}

genswitch(p,n) register struct sw *p;{
	/*	p points to an array of structures, each consisting
		of a constant value and a label.
		The first is >=0 if there is a default label;
		its value is the label number
		The entries p[1] to p[n] are the nontrivial cases
		*/
	register i;
	register CONSZ j, range;
	register dlab, swlab;

	range = p[n].sval-p[1].sval;

	if( range>0 && range <= 3*n && n>=4 ){ /* implement a direct switch */

		dlab = p->slab >= 0 ? p->slab : getlab();

		if( p[1].sval ){
			printf( "	subl	#" );
			printf( CONFMT, p[1].sval );
			printf( ",d0\n" );
			}

		/* note that this is a cl; it thus checks
		   for numbers below range as well as out of range.
		   */
		printf( "	cmpl	#%ld,d0\n", range );
		printf( "	bhi	.L%d\n", dlab );

		printf( "	addw	d0,d0\n" );
		printf( "	movw	pc@(6,d0:w),d0\n" );
		printf( "	jmp	pc@(2,d0:w)\n" );

		/* output table */

		printf( ".L%d = .\n", swlab=getlab() );

		for( i=1,j=p[1].sval; i<=n; ++j ){

			printf( "	.word	.L%d-.L%d\n", ( j == p[i].sval ) ?
				p[i++].slab : dlab, swlab );
			}

		if( p->slab< 0 ) deflab( dlab );
		return;

		}

	genbinary(p,1,n,0);
}

genbinary(p,lo,hi,lab)
  register struct sw *p;
  {	register int i,lab1;

	if (lab) printf(".L%d:",lab);	/* print label, if any */

	if (hi-lo > 4) {		/* if lots more, do another level */
	  i = lo + ((hi-lo)>>1);	/* index at which we'll break this time */
	  printf( "	cmpl	#" );
	  printf( CONFMT, p[i].sval );
	  printf( ",d0\n	beq	.L%d\n", p[i].slab );
	  printf( "	bgt	.L%d\n", lab1=getlab() );
	  genbinary(p,lo,i-1,0);
	  genbinary(p,i+1,hi,lab1);
	} else {			/* simple switch code for remaining cases */
	  for( i=lo; i<=hi; ++i ) {
	    printf( "	cmpl	#" );
	    printf( CONFMT, p[i].sval );
	    printf( ",d0\n	beq	.L%d\n", p[i].slab );
	  }
	  if( p->slab>=0 ) branch( p->slab );
	}
}

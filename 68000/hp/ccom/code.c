/* file code.c */

# include <stdio.h>
# include <signal.h>

# include "mfile1"

extern int usedregs;	/* bit == 1 if reg was used in subroutine */
extern char *rnames[];
/* the next 4 were ints - MFM */
short proflag;
short sysflag;  /* gen special 'system' code -- omit stack tests */
short strftn = 0;	/* is the current function one which returns a value */
short dataflag = 0;	/* MFM - true if .data was seen last */
FILE *tmpfile;
FILE *outfile = stdout;

branch( n ){
	/* output a branch to label n */
	/* exception is an ordinary function branching to retlab: then, return */
	if( n == retlab && !strftn ) printf( "	jra	?L%d\n", retlab );
	else printf( "	jra	?L%d\n", n );
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
		if (dataflag) {
		  printf( "	.text\n" );
		  dataflag = 0;
		  }
		break;

	case DATA:
	case ADATA:
		outfile = stdout;
		if( temp != DATA && temp != ADATA && (dataflag == 0))
			printf( "	.data\n" );
		dataflag++;
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
	fprintf( outfile, "?L%d:\n", n );
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
		register short i, size;
		short sizesv;	/* sizesv added - MFM */

		p = &stab[curftn];

		deflab( retlab );
		retlab = getlab();

		stlab = getlab();
		printf( "	move.l	?d0,?a0\n" );
		printf( "	move.l	#?L%d,?a1\n" , stlab );
		sizesv = size = tsize( DECREF(p->stype), p->dimoff, p->sizoff ) / SZCHAR;
		while( size ){ /* simple load/store loop */
		  i = (size > 2) ? 4 : 2;
		  printf("	move.%c	(?a0)+,(?a1)+\n", i==2 ? 'w' : 'l');
		  size -= i;
		}
		printf( "	move.l	#?L%d,?d0\n", stlab );
		printf( "	.bss\n	.even\n?L%d:	*=*+%d\n	.text\n", stlab, sizesv );	/* modified - MFM */
		dataflag = 0;
		/* turn off strftn flag, so return sequence will be generated */
		strftn = 0;
		}
	branch( retlab );
	p2bend();
	}

bfcode( a, n ) int a[]; {
	/* code for the beginning of a function; a is an array of
		indices in stab for the arguments; n is the number */
	register short i;		/* MFM */
	register temp;
	register struct symtab *p;
	int off;
	unsigned char type;		/* MFM */

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
		printf( "	move.l	#?L%d,?a0\n", plab );
		printf( "	jbsr	mcount\n" );
		printf( "	.data\n?L%d:	.long 0\n	.text\n", plab);		
		dataflag = 0;
		}

	/* routine prolog */

	printf( "	link	?a6,#-_F%d\n", ftnno );
#ifdef protest		/* MFM */
	printf("        trap 	13 	| trap to support Brent's profiling\n");
#endif
	if (sysflag==0) printf( "	tst.b	-_M%d-8(?a7)\n", ftnno);
		/* +4 for return address of JSR ; +4 for the link *//* MFM */
	printf( "	movem.l	#_S%d,-_F%d(?a6)\n", ftnno, ftnno );
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
			printf( "	move.%c	%d(?a6),%s\n", type, p->offset/SZCHAR,
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
	for( i=1; i<=n; i++ ) printf( "	.long	0\n" );
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
	register short i;
	int fdef = 0;
	int r;

	for( i=1; i<argc; ++i ) {
		if( argv[i][0] == '-' && argv[i][1] == 'X' && argv[i][2] == 'p' ) {
			proflag = 1;
			}
		if( argv[i][0] == '-' && argv[i][1] == '!') {
			if (argv[i][2] == 's')  sysflag = 1;
			if (argv[i][2] == 'P')  sysflag = 1;
		}
		if( *(argv[i]) != '-' ) switch( fdef++ ) {
			case 0:
			case 1:
				if( freopen(argv[i], fdef==1 ? "r" : "w", fdef==1 ? stdin : stdout) == NULL) {
					fprintf(stderr, "ccom:can't open %s\n", argv[i]);
					exit(1);
				}
				break;

			default:
				;
			}
	}

	mktemp(tmpname);
	if(signal( SIGHUP, SIG_IGN) != SIG_IGN) signal(SIGHUP, dexit);
	if(signal( SIGINT, SIG_IGN) != SIG_IGN) signal(SIGINT, dexit);
	if(signal( SIGTERM, SIG_IGN) != SIG_IGN) signal(SIGTERM, dexit);
	tmpfile = fopen( tmpname, "w" );
	if(tmpfile == NULL) cerror( "Cannot open temp file" );

	r = mainp1( argc, argv );	/* mainp1 will in turn call mainp2 */

	tmpfile = freopen( tmpname, "r", tmpfile );

	/* now copy all from tmpfile to stdout - MFM */
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

genswitch(p,n) register n; register struct sw *p;{	/* MFM */
	/*	p points to an array of structures, each consisting
		of a constant value and a label.
		The first is >=0 if there is a default label;
		its value is the label number
		The entries p[1] to p[n] are the nontrivial cases
		*/
	register short i;				/* MFM */
	register CONSZ j, range;
	register dlab, swlab;

	range = p[n].sval-p[1].sval;

	if( range>0 && range <= 3*n && n>=4 ){ /* implement a direct switch */

		dlab = p->slab >= 0 ? p->slab : getlab();

		if( p[1].sval ){
			printf( "	sub.l	#" );
			printf( CONFMT, p[1].sval );
			printf( ",?d0\n" );
			}

		/* note that this is a cl; it thus checks
		   for numbers below range as well as out of range.
		   */
		printf( "	cmp.l	#%ld,?d0\n", range );
		printf( "	jhi	?L%d\n", dlab );

		printf( "	add.w	?d0,?d0\n" );
		printf( "	move.w	8(?pc,?d0.w),?d0\n" ); /* MFM */
		printf( "	jmp	4(?pc,?d0.w)\n" );	/* MFM */
		/* note */

		/* output table */

		printf( "?L%d = *\n", swlab=getlab() );

		for( i=1,j=p[1].sval; i<=n; ++j ){

			printf( "	.word	?L%d-?L%d\n", ( j == p[i].sval ) ?
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

	if (lab) printf("?L%d:",lab);	/* print label, if any */

	if (hi-lo > 4) {		/* if lots more, do another level */
	  i = lo + ((hi-lo)>>1);	/* index at which we'll break this time */
	  printf( "	cmp.l	#" );
	  printf( CONFMT, p[i].sval );
	  printf( ",?d0\n	jeq	?L%d\n", p[i].slab );
	  printf( "	jgt	?L%d\n", lab1=getlab() );
	  genbinary(p,lo,i-1,0);
	  genbinary(p,i+1,hi,lab1);
	} else {			/* simple switch code for remaining cases */
	  for( i=lo; i<=hi; ++i ) {
	    printf( "	cmp.l	#" );
	    printf( CONFMT, p[i].sval );
	    printf( ",?d0\n	jeq	?L%d\n", p[i].slab );
	  }
	  if( p->slab>=0 ) branch( p->slab );
	}
}

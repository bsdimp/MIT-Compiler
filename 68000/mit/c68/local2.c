# include "mfile2"
/* a lot of the machine dependent parts of the second pass */

# define BITMASK(n) ((1L<<n)-1)

lineid( l, fn ) char *fn; {
	/* identify line l and file fn */
	printf( "|	line %d, file %s\n", l, fn );
	}

int usedregs;	/* flag word for registers used in current routine */
int maxtoff = 0;

cntbits(i)
  register int i;
  {	register int j,ans;

	for (ans=0, j=0; i!=0 && j<16; j++) { if (i&1) ans++; i>>= 1; }
	return(ans);
}

eobl2(){
	extern int retlab;
	OFFSZ spoff;	/* offset from stack pointer */

	spoff = maxoff;
	spoff /= SZCHAR;
	SETOFF(spoff,2);
	usedregs &= 036374;	/* only save regs used for reg vars */
	spoff += 4*cntbits(usedregs);	/* save at base of stack frame */
	printf( ".L%d:	moveml	.a6@(-_F%d),#%d\n", retlab, ftnno, usedregs );
	printf( "	unlk	.a6\n" );
	printf( "	rts\n" );
	printf( "_F%d = %ld\n", ftnno, spoff );
	printf( "_S%d = %d\n", ftnno, usedregs );
	printf( "| M%d = %d\n", ftnno, maxtoff );
	maxtoff = 0;
	if( fltused ) {
		fltused = 0;
		printf( "	.globl	fltused\n" );
		}
	}

struct hoptab { int opmask; char * opstring; } ioptab[]= {

	ASG PLUS, "add",
	ASG MINUS, "sub",
	ASG OR,	"or",
	ASG AND, "and",
	ASG ER,	"eor",
	ASG MUL, "mul",
	ASG DIV, "div",
	ASG MOD, "div",
	ASG LS,	"sl",
	ASG RS,	"sr",

	-1, ""    };

hopcode( f, o ){
	/* output the appropriate string from the above table */

	register struct hoptab *q;

	for( q = ioptab;  q->opmask>=0; ++q ){
		if( q->opmask == o ){
			printf( "%s", q->opstring );
			if( f == 'F' ) printf( "f" );
			return;
			}
		}
	cerror( "no hoptab for %s", opst[o] );
	}

char *
rnames[]= {  /* keyed to register number tokens */

	".d0", ".d1", ".d2", ".d3", ".d4", ".d5", ".d6", ".d7",
	".a0", ".a1", ".a2", ".a3", ".a4", ".a5", ".a6", ".sp"
	};

int rstatus[] = {
	SAREG|STAREG, SAREG|STAREG,
	SAREG|STAREG, SAREG|STAREG,
	SAREG|STAREG, SAREG|STAREG,
	SAREG|STAREG, SAREG|STAREG,

	SBREG|STBREG, SBREG|STBREG,
	SBREG|STBREG, SBREG|STBREG,
	SBREG|STBREG, SBREG|STBREG,
	SBREG,	      SBREG,
	};

NODE *brnode;
int brcase;

int toff = 0; /* number of stack locations used for args */

zzzcode( p, c ) NODE *p; {
	register m,temp;
	switch( c ){

	case 'C':
		switch (p->in.left->in.op) {
		  case ICON:	printf("\tjsr\t");
				acon(p->in.left);
				return;

		  case REG:	printf("\tjsr\t");
				adrput(p->in.left);
				printf("@");
				return;

		  case NAME:
		  case OREG:	printf("\tmovl\t");
				adrput(p->in.left);
				printf(",.a0\n\tjsr\t.a0@");
				return;

		  default:	cerror("bad subroutine name");
		}

	case 'L':
		m = p->in.left->in.type;
		goto suffix;

	case 'R':
		m = p->in.right->in.type;
		goto suffix;

	case 'B':
		m = p->in.type;		/* fall into suffix: */

	suffix:	if( m == CHAR || m == UCHAR ) printf( "b" );
		else if( m == SHORT || m == USHORT ) printf( "w" );
		else printf( "l" );
		return;

	case 'N':  /* logical ops, turned into 0-1 */
		/* use register given by register 1 */
		cbgen( 0, m=getlab(), 'I' );
		deflab( p->bn.label );
		printf( "	clrl	%s\n", rnames[temp = getlr( p, '1' )->tn.rval] );
		usedregs |= 1<<temp;
		deflab( m );
		return;

	case 'I':
		cbgen( p->in.op, p->bn.label, c );
		return;

		/* stack management macros */
	case '-':
		printf( ".sp@-" );
	case 'P':
		toff += 4;
		if (toff > maxtoff) maxtoff = toff;
		return;

	case '0':
		toff = 0; return;

	case '~':
		/* complimented CR */
		p->in.right->tn.lval = ~p->in.right->tn.lval;
		conput( getlr( p, 'R' ) );
		p->in.right->tn.lval = ~p->in.right->tn.lval;
		return;

	case 'M':
		/* negated CR */
		p->in.right->tn.lval = -p->in.right->tn.lval;
	case 'O':
		conput( getlr( p, 'R' ) );
		p->in.right->tn.lval = -p->in.right->tn.lval;
		return;

	case 'T':
		/* Truncate longs for type conversions:
		    INT|UNSIGNED -> CHAR|UCHAR|SHORT|USHORT
		   increment offset to second word */

		m = p->in.type;
		p = p->in.left;
		switch( p->in.op ){
		case NAME:
		case OREG:
			if (p->in.type==SHORT || p->in.type==USHORT)
			  p->tn.lval += (m==CHAR || m==UCHAR) ? 1 : 0;
			else p->tn.lval += (m==CHAR || m==UCHAR) ? 3 : 2;
			return;
		case REG:
			return;
		default:
			cerror( "Illegal ZT type conversion" );
			return;

			}

	case 'U':
		cerror( "Illegal ZU" );
		/* NO RETURN */

	case 'W':	/* structure size */
		if( p->in.op == STASG )
			printf( "%d", p->stn.stsize);
		else	cerror( "Not a structure" );
		return;

	case 'S':  /* structure assignment */
		{
			register NODE *l, *r;
			register size, i;

			if( p->in.op == STASG ){
				l = p->in.left;
				r = p->in.right;
				}
			else if( p->in.op == STARG ){  /* store an arg onto the stack */
				r = p->in.left;
				}
			else cerror( "STASG bad" );

			if( r->in.op == ICON ) r->in.op = NAME;
			else if( r->in.op == REG ) r->in.op = OREG;
			else if( r->in.op != OREG ) cerror( "STASG-r" );

			size = p->stn.stsize;

			r->tn.lval += size;
			l->tn.lval += size;

			while( size ){ /* simple load/store loop */
				i = (size > 2) ? 4 : 2;
				r->tn.lval -= i;
				expand( r, FOREFF,(i==2)?"\tmovw\tAR,":"\tmovl\tAR," );
				l->tn.lval -= i;
				expand( l, FOREFF, "AR\n" );
				size -= i;
			}

			if( r->in.op == NAME ) r->in.op = ICON;
			else if( r->in.op == OREG ) r->in.op = REG;

			}
		break;

	default:
		cerror( "illegal zzzcode" );
		}
	}

rmove( rt, rs, t ) TWORD t; {
	if ( t == DOUBLE ) {
	  printf( "	movl	%s,%s\n", rnames[rs+1], rnames[rt+1] );
	  usedregs |= 1<<(rs+1);
	  usedregs |= 1<<(rt+1);
	}
	printf( "	movl	%s,%s\n", rnames[rs], rnames[rt] );
	usedregs |= 1<<rs;
	usedregs |= 1<<rt;
	}

struct respref
respref[] = {
	INTAREG|INTBREG,	INTAREG|INTBREG,
	INAREG|INBREG,	INAREG|INBREG|SOREG|STARREG|SNAME|STARNM|SCON,
	INTEMP,	INTEMP,
	FORARG,	FORARG,
	INTAREG,	SOREG|SNAME|INAREG,
	0,	0 };

setregs(){ /* set up temporary registers */
	register i;
	register int naregs = (maxtreg>>8)&0377;

	/* use any unused variable registers as scratch registers */
	maxtreg & = 0377;
	fregs = maxtreg>=MINRVAR ? maxtreg + 1 : MINRVAR;
	if( xdebug ){
		/* -x changes number of free regs to 2, -xx to 3, etc. */
		if( (xdebug+1) < fregs ) fregs = xdebug+1;
		}

	for( i=MINRVAR; i<=MAXRVAR; i++ )
		rstatus[i] = i<fregs ? SAREG|STAREG : SAREG;
	for( i=MINRVAR; i<=MAXRVAR; i++ )
		rstatus[i+8] = i<naregs ? SBREG|STBREG : SBREG;
	}

szty(t) TWORD t; { /* size, in words, needed to hold thing of type t */
	/* really is the number of registers to hold type t */
	return(t==DOUBLE ? 2 : 1);
	}

rewfld( p ) NODE *p; {
	return(1);
	}

callreg(p) NODE *p; {
	return( D0 );
	}

shltype( o, p ) NODE *p; {
	if( o == NAME|| o==REG || o == ICON || o == OREG ) return( 1 );
	return( o==UNARY MUL && shumul(p->in.left) );
	}

flshape( p ) register NODE *p; {
	register o = p->in.op;
	if( o==NAME || o==REG || o==ICON || o==OREG ) return( 1 );
	return( o==UNARY MUL && shumul(p->in.left)==STARNM );
	}

shtemp( p ) register NODE *p; {
	if( p->in.op == UNARY MUL ) p = p->in.left;
	if( p->in.op == REG || p->in.op == OREG ) return( !istreg( p->tn.rval ) );
	return( p->in.op == NAME || p->in.op == ICON );
	}

spsz( t, v ) TWORD t; CONSZ v; {

	/* is v the size to increment something of type t */

	if( !ISPTR(t) ) return( 0 );
	t = DECREF(t);

	if( ISPTR(t) ) return( v == 4 );

	switch( t ){

	case UCHAR:
	case CHAR:
		return( v == 1 );

	case SHORT:
	case USHORT:
		return( v == 2 );

	case INT:
	case UNSIGNED:
	case FLOAT:
		return( v == 4 );

	case DOUBLE:
		return( v == 8 );
		}

	return( 0 );
	}

indexreg( p ) register NODE *p; {
	if ( p->in.op==REG && p->tn.rval>=A0 && p->tn.rval<=SP) return(1);
	return(0);
}

shumul( p ) register NODE *p; {
	register o;

	o = p->in.op;
	if( indexreg(p) ) return( STARNM );

	if( o == INCR && indexreg(p->in.left) && p->in.right->in.op==ICON &&
	    p->in.right->in.name[0] == '\0' &&
	    spsz( p->in.left->in.type, p->in.right->tn.lval ) )
		return( STARREG );

	return( 0 );
	}

adrcon( val ) CONSZ val; {
	printf( CONFMT, val );
	}

conput( p ) register NODE *p; {
	switch( p->in.op ){

	case ICON:
		acon( p );
		return;

	case REG:
		printf( "%s", rnames[p->tn.rval] );
		usedregs |= 1<<p->tn.rval;
		return;

	default:
		cerror( "illegal conput" );
		}
	}

insput( p ) NODE *p; {
	cerror( "insput" );
	}

upput( p ) NODE *p; {
	/* output the address of the second word in the
	   pair pointed to by p (for LONGs)*/
	CONSZ save;

	if( p->in.op == FLD ){
		p = p->in.left;
		}

	save = p->tn.lval;
	switch( p->in.op ){

	case NAME:
		p->tn.lval += SZINT/SZCHAR;
		acon( p );
		break;

	case ICON:
		/* addressable value of the constant */
		p->tn.lval &= BITMASK(SZINT);
		printf( "#" );
		acon( p );
		break;

	case REG:
		printf( "%s", rnames[p->tn.rval+1] );
		usedregs |= 1<<(p->tn.rval + 1);
		break;

	case OREG:
		p->tn.lval += SZINT/SZCHAR;
		if( p->tn.rval == A6 ){  /* in the argument region */
			if( p->in.name[0] != '\0' ) werror( "bad arg temp" );
			}
		printf( "%s@", rnames[p->tn.rval] );
		usedregs |= 1<<p->tn.rval;
		if( p->tn.lval != 0 || p->in.name[0] != '\0' )
		  { printf("("); acon( p ); printf(")"); }
		break;

	default:
		cerror( "illegal upper address" );
		break;

		}
	p->tn.lval = save;

	}

adrput( p ) register NODE *p; {
	/* output an address, with offsets, from p */

	if( p->in.op == FLD ){
		p = p->in.left;
		}
	switch( p->in.op ){

	case NAME:
		acon( p );
		return;

	case ICON:
		/* addressable value of the constant */
		if( szty( p->in.type ) == 2 ) {
			/* print the high order value */
			CONSZ save;
			save = p->tn.lval;
			p->tn.lval = ( p->tn.lval >> SZINT ) & BITMASK(SZINT);
			printf( "#" );
			acon( p );
			p->tn.lval = save;
			return;
			}
		printf( "#" );
		acon( p );
		return;

	case REG:
		printf( "%s", rnames[p->tn.rval] );
		usedregs |= 1<<p->tn.rval;
		return;

	case OREG:
		if( p->tn.rval == A6 ){  /* in the argument region */
			if( p->in.name[0] != '\0' ) werror( "bad arg temp" );
			printf( ".a6@(" );
			printf( CONFMT, p->tn.lval );
			printf( ")" );
			return;
			}
		printf( "%s@", rnames[p->tn.rval] );
		usedregs |= 1<<p->tn.rval;
		if( p->tn.lval != 0 || p->in.name[0] != '\0' )
		  { printf("("); acon( p ); printf(")"); }
		break;

	case UNARY MUL:
		/* STARNM or STARREG found */
		if( tshape(p, STARNM) ) {
			adrput( p->in.left);
			printf( "@" );
			}
		else {	/* STARREG - really auto inc or dec */
			/* turn into OREG so replacement node will
			   reflect the value of the expression */
			register i;
			register NODE *q, *l;

			l = p->in.left;
			q = l->in.left;
			p->in.op = OREG;
			p->in.rall = q->in.rall;
			p->tn.lval = q->tn.lval;
			p->tn.rval = q->tn.rval;
			for( i=0; i<NCHNAM; i++ )
				p->in.name[i] = q->in.name[i];
			if( l->in.op == INCR ) {
				adrput( p );
				printf( "+" );
				p->tn.lval -= l->in.right->tn.lval;
				}
			else {	/* l->in.op == ASG MINUS */
				printf( "-" );
				adrput( p );
				}
			tfree( l );
		}
		return;

	default:
		cerror( "illegal address" );
		return;

		}

	}

acon( p ) register NODE *p; { /* print out a constant */

	if( p->in.name[0] == '\0' ){	/* constant only */
		printf( CONFMT, p->tn.lval);
		}
	else if( p->tn.lval == 0 ) {	/* name only */
		printf( "%.8s", p->in.name );
		}
	else {				/* name + offset */
		printf( "%.8s+", p->in.name );
		printf( CONFMT, p->tn.lval );
		}
	}

genscall( p, cookie ) register NODE *p; {
	/* structure valued call */
	return( gencall( p, cookie ) );
	}

gencall( p, cookie ) register NODE *p; {
	/* generate the call given by p */
	register temp;
	register m;

	if( p->in.right ) temp = argsize( p->in.right );
	else temp = 0;

	if( p->in.right ){ /* generate args */
		genargs( p->in.right );
		}

	if( !shltype( p->in.left->in.op, p->in.left ) ) {
		order( p->in.left, INBREG|SOREG );
		}

	p->in.op = UNARY CALL;
	m = match( p, INTAREG|INTBREG );
	popargs( temp );
	return(m != MDONE);
	}

popargs( size ) register size; {
	/* pop arguments from stack */

	toff -= size/2;
	if( toff == 0 && size >= 2 ) size -= 2;
	switch( size ) {
	case 0:
		break;
	default:
		printf( "\t%s\t#%d,.sp\n", size<=8 ? "addql":"addl", size);
		}
	}

char *
ccbranches[] = {
	"	beq	.L%d\n",
	"	bne	.L%d\n",
	"	ble	.L%d\n",
	"	blt	.L%d\n",
	"	bge	.L%d\n",
	"	bgt	.L%d\n",
	"	bls	.L%d\n",
	"	bcs	.L%d\n",		/* blo */
	"	bcc	.L%d\n",		/* bhis */
	"	bhi	.L%d\n",
	};

/*	long branch table

   This table, when indexed by a logical operator,
   selects a set of three logical conditions required
   to generate long comparisons and branches.  A zero
   entry indicates that no branch is required.
   E.G.:  The <= operator would generate:
	cmp	AL,AR
	jlt	lable	/ 1st entry LT -> lable
	jgt	1f	/ 2nd entry GT -> 1f
	cmp	UL,UR
	jlos	lable	/ 3rd entry ULE -> lable
   1:
 */

int lbranches[][3] = {
	/*EQ*/	0,	NE,	EQ,
	/*NE*/	NE,	0,	NE,
	/*LE*/	LT,	GT,	ULE,
	/*LT*/	LT,	GT,	ULT,
	/*GE*/	GT,	LT,	UGE,
	/*GT*/	GT,	LT,	UGT,
	/*ULE*/	ULT,	UGT,	ULE,
	/*ULT*/	ULT,	UGT,	ULT,
	/*UGE*/	UGT,	ULT,	UGE,
	/*UGT*/	UGT,	ULT,	UGT,
	};

/* logical relations when compared in reverse order (cmp R,L) */
extern short revrel[] ;

cbgen( o, lab, mode ) { /*   printf conditional and unconditional branches */
	register *plb;
	int lab1f;

	if( o == 0 ) printf( "	bra	.L%d\n", lab );
	else	if( o > UGT ) cerror( "bad conditional branch: %s", opst[o] );
	else {
		switch( brcase ) {

		case 'A':
		case 'C':
			plb = lbranches[ o-EQ ];
			lab1f = getlab();
			expand( brnode, FORCC, brcase=='C' ? "\tcmp\tAL,AR\n" : "\ttst\tAR\n" );
			if( *plb != 0 )
				printf( ccbranches[*plb-EQ], lab);
			if( *++plb != 0 )
				printf( ccbranches[*plb-EQ], lab1f);
			expand( brnode, FORCC, brcase=='C' ? "\tcmp\tUL,UR\n" : "\ttst\tUR\n" );
			printf( ccbranches[*++plb-EQ], lab);
			deflab( lab1f );
			reclaim( brnode, RNULL, 0 );
			break;

		default:
			if( mode=='F' ) o = revrel[ o-EQ ];
			printf( ccbranches[o-EQ], lab );
			break;
			}

		brcase = 0;
		brnode = 0;
		}
	}

nextcook( p, cookie ) NODE *p; {
	/* we have failed to match p with cookie; try another */
	if( cookie == FORREW ) return( 0 );  /* hopeless! */
	if( !(cookie&(INTAREG|INTBREG)) ) return( INTAREG|INTBREG );
	if( !(cookie&INTEMP) && asgop(p->in.op) ) return( INTEMP|INAREG|INTAREG|INTBREG|INBREG );
	return( FORREW );
	}

lastchance( p, cook ) NODE *p; {
	/* forget it! */
	return(0);
	}

struct functbl {
	int fop;
	TWORD ftype;
	char *func;
	} opfunc[] = {
	MUL,		INT,	"lmul",
	DIV,		INT,	"ldiv",
	MOD,		INT,	"lrem",
	ASG MUL,	INT,	"almul",
	ASG DIV,	INT,	"aldiv",
	ASG MOD,	INT,	"alrem",
	MUL,		UNSIGNED,	"ulmul",
	DIV,		UNSIGNED,	"uldiv",
	MOD,		UNSIGNED,	"ulrem",
	ASG MUL,	UNSIGNED,	"aulmul",
	ASG DIV,	UNSIGNED,	"auldiv",
	ASG MOD,	UNSIGNED,	"aulrem",
	PLUS,		DOUBLE,	"fadd",
	MINUS,		DOUBLE, "fsub",
	MUL,		DOUBLE, "fmul",
	DIV,		DOUBLE, "fdiv",
	UNARY MINUS,	DOUBLE, "fneg",
	UNARY MINUS,	FLOAT,	"fneg",
	ASG PLUS,	DOUBLE,	"afadd",
	ASG MINUS,	DOUBLE, "afsub",
	ASG MUL,	DOUBLE, "afmul",
	ASG DIV,	DOUBLE, "afdiv",
	ASG PLUS,	FLOAT,	"afaddf",
	ASG MINUS,	FLOAT,	"afsubf",
	ASG MUL,	FLOAT,	"afmulf",
	ASG DIV,	FLOAT,	"afdivf",
	0,	0,	0 };

hardops(p)  register NODE *p; {
	/* change hard to do operators into function calls. */
	register NODE *q;
	register struct functbl *f;
	register o;
	register TWORD t;

	o = p->in.op;
	t = p->in.type;

	if (o==SCONV) { hardconv(p); return; }

	for( f=opfunc; f->fop; f++ ) {
		if( o==f->fop && t==f->ftype ) goto convert;
		}
	return;

	/* need address of left node for ASG OP */
	/* WARNING - this won't work for long in a REG */
	convert:

	/* special hack to notice when hardware can do multiplication -- used
	 * in conjuction with processing done by optim2() below
	 */
	if (o==MUL && t==INT && p->in.left->in.type==SHORT && p->in.right->in.type==SHORT)
	  return;

	if( asgop( o ) ) {
		switch( p->in.left->in.op ) {

		case UNARY MUL:	/* convert to address */
			p->in.left->in.op = FREE;
			p->in.left = p->in.left->in.left;
			break;

		case NAME:	/* convert to ICON pointer */
			p->in.left->in.op = ICON;
			p->in.left->in.type = INCREF( p->in.left->in.type );
			break;

		case OREG:	/* convert OREG to address */
			p->in.left->in.op = REG;
			p->in.left->in.type = INCREF( p->in.left->in.type );
			if( p->in.left->tn.lval != 0 ) {
				q = talloc();
				q->in.op = PLUS;
				q->in.rall = NOPREF;
				q->in.type = p->in.left->in.type;
				q->in.left = p->in.left;
				q->in.right = talloc();

				q->in.right->in.op = ICON;
				q->in.right->in.rall = NOPREF;
				q->in.right->in.type = INT;
				q->in.right->in.name[0] = '\0';
				q->in.right->tn.lval = p->in.left->tn.lval;
				q->in.right->tn.rval = 0;

				p->in.left->tn.lval = 0;
				p->in.left = q;
				}
			break;

		/* rewrite "foo <op>= bar" as "foo = foo <op> bar" for foo in a reg */
		case REG:
			q = talloc();
			q->in.op = p->in.op - 1;	/* change <op>= to <op> */
			q->in.rall = p->in.rall;
			q->in.type = p->in.type;
			q->in.left = talloc();
			q->in.right = p->in.right;
			p->in.op = ASSIGN;
			p->in.right = q;
			q = q->in.left;			/* make a copy of "foo" */
			q->in.op = p->in.left->in.op;
			q->in.rall = p->in.left->in.rall;
			q->in.type = p->in.left->in.type;
			q->tn.lval = p->in.left->tn.lval;
			q->tn.rval = p->in.left->tn.rval;
			hardops(p->in.right);
			return;

		default:
			cerror( "Bad address for hard ops" );
			/* NO RETURN */

			}
		}

	/* build comma op for args to function */
	if ( optype(p->in.op) == BITYPE ) {
	  q = talloc();
	  q->in.op = CM;
	  q->in.rall = NOPREF;
	  q->in.type = INT;
	  q->in.left = p->in.left;
	  q->in.right = p->in.right;
	} else q = p->in.left;

	p->in.op = CALL;
	p->in.right = q;

	/* put function name in left node of call */
	p->in.left = q = talloc();
	q->in.op = ICON;
	q->in.rall = NOPREF;
	q->in.type = INCREF( FTN + p->in.type );
	strcpy( q->in.name, f->func );
	q->tn.lval = 0;
	q->tn.rval = 0;

	return;

	}

/* do fix and float conversions */
hardconv(p)
  register NODE *p;
  {	register NODE *q;
	register TWORD t,tl;
	int m,ml;

	t = p->in.type;
	tl = p->in.left->in.type;

	m = t==DOUBLE || t==FLOAT;
	ml = tl==DOUBLE || tl==FLOAT;

	if (m==ml) return;

	p->in.op = CALL;
	p->in.right = p->in.left;

	/* put function name in left node of call */
	p->in.left = q = talloc();
	q->in.op = ICON;
	q->in.rall = NOPREF;
	q->in.type = INCREF( FTN + p->in.type );
	strcpy( q->tn.name, m ? "float" : "fix" );
	q->tn.lval = 0;
	q->tn.rval = 0;
}

/* return 1 if node is a SCONV from short to int */
shortconv( p )
  register NODE *p;
  {	if ( p->in.op==SCONV && p->in.type==INT && p->in.left->in.type==SHORT)
	  return( 1 );
	return( 0 );
}

/* do local tree transformations and optimizations */
optim2( p )
  register NODE *p;
  {	register NODE *q;

	/* multiply of two shorts to produce an int can be done directly
	 * in the hardware.
	 */
	if ( p->in.op==MUL && p->in.type==INT && shortconv(p->in.left) &&
	     (shortconv(p->in.right) || (p->in.right->in.op==ICON &&
	      p->in.right->in.name[0] == '\0' &&
	      p->in.right->tn.lval>=-32768L && p->in.right->tn.lval<=32767L)))
	{
	  p->in.left = (q = p->in.left)->in.left;
	  q->in.op = FREE;
	  if ( p->in.right->in.op==ICON ) p->in.right->in.type = SHORT;
	  else {
	    p->in.right = (q = p->in.right)->in.left;
	    q->in.op = FREE;
	  }
	}

	/* change <flt exp>1 <logop> <flt exp>2 to
	 * (<exp>1 - <exp>2) <logop> 0.0
	 */
	if (logop(p->in.op) &&
	    ((q = p->in.left)->in.type==FLOAT || q->in.type==DOUBLE) &&
	    ((q = p->in.right)->in.type==FLOAT || q->in.type==DOUBLE)) {
	  q = talloc();
	  q->in.op = MINUS;
	  q->in.rall = NOPREF;
	  q->in.type = DOUBLE;
	  q->in.left = p->in.left;
	  q->in.right = p->in.right;
	  p->in.left = q;
	  p->in.right = q = talloc();
	  q->tn.op = ICON;
	  q->tn.type = DOUBLE;
	  q->tn.name[0] = '\0';
	  q->tn.rval = 0;
	  q->tn.lval = 0;
	}
}

myreader(p) register NODE *p; {
	walkf( p, optim2 );
	walkf( p, hardops );	/* convert ops to function calls */
	canon( p );		/* expands r-vals for fileds */
	toff = 0;  /* stack offset swindle */
	}

special( p, shape ) register NODE *p; {
	/* special shape matching routine */

	switch( shape ) {

	case SCCON:
		if( p->in.op == ICON && p->in.name[0]=='\0' && p->tn.lval>= -128 && p->tn.lval <=127 ) return( 1 );
		break;

	case SICON:
		if( p->in.op == ICON && p->in.name[0]=='\0' && p->tn.lval>= 0 && p->tn.lval <=32767 ) return( 1 );
		break;

	case S8CON:
		if( p->in.op == ICON && p->in.name[0]=='\0' && p->tn.lval>= 1 && p->tn.lval <= 8) return( 1 );
		break;

	default:
		cerror( "bad special shape" );

		}

	return( 0 );
	}

# ifndef ONEPASS
main( argc, argv ) char *argv[]; {
	return( mainp2( argc, argv ) );
	}
# endif

# ifdef MULTILEVEL
# include "mldec.h"

struct ml_node mltree[] ={

DEFINCDEC,	INCR,	0,
	INCR,	SANY,	TANY,
		OPANY,	SAREG|STAREG,	TANY,
		OPANY,	SCON,	TANY,

DEFINCDEC,	ASG MINUS,	0,
	ASG MINUS,	SANY,	TANY,
		REG,	SANY,	TANY,
		ICON,	SANY,	TANY,

TSOREG,	1,	0,
	UNARY MUL,	SANY,	TANY,
		REG,	SANY,	TANY,

TSOREG,	2,	0,
	UNARY MUL,	SANY,	TANY,
		PLUS,	SANY,	TANY,
			REG,	SANY,	TANY,
			ICON,	SANY,	TCHAR|TUCHAR|TSHORT|TUSHORT|TINT|TUNSIGNED|TPOINT,

TSOREG,	2,	0,
	UNARY MUL,	SANY,	TANY,
		MINUS,	SANY,	TANY,
			REG,	SANY,	TANY,
			ICON,	SANY,	TCHAR|TUCHAR|TSHORT|TUSHORT|TINT|TUNSIGNED|TPOINT,
0,0,0};
# endif

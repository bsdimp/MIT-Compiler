# include "mfile1"

unsigned int offsz;

struct instk {
	int in_sz;   /* size of array element */
	int in_x;    /* current index for structure member in structure initializations */
	int in_n;    /* number of initializations seen */
	int in_s;    /* sizoff */
	int in_d;    /* dimoff */
	TWORD in_t;    /* type */
	int in_id;   /* stab index */
	int in_fl;   /* flag which says if this level is controlled by {} */
	OFFSZ in_off;  /* offset of the beginning of this level */
	}
instack[10],
*pstk;

	/* defines used for getting things off of the initialization stack */


struct symtab *relook();


int ddebug = 0;

struct symtab * mknonuniq();

defid( q, class )  NODE *q; {
	register struct symtab *p;
	int idp;
	TWORD type;
	TWORD stp;
	int scl;
	int dsym, ddef;
	int slev, temp;

	if( q == NIL ) return;  /* an error was detected */

	if( q < node || q >= &node[TREESZ] ) cerror( "defid call" );

	idp = q->tn.rval;

	if( idp < 0 ) cerror( "tyreduce" );
	p = &stab[idp];

# ifndef BUG1
	if( ddebug ){
		printf( "defid( %.8s (%d), ", p->sname, idp );
		tprint( q->in.type );
		printf( ", %s, (%d,%d) ), level %d\n", scnames(class), q->fn.cdim, q->fn.csiz, blevel );
		}
# endif

	fixtype( q, class );

	type = q->in.type;
	class = fixclass( class, type );

	stp = p->stype;
	slev = p->slevel;

# ifndef BUG1
	if( ddebug ){
		printf( "	modified to " );
		tprint( type );
		printf( ", %s\n", scnames(class) );
		printf( "	previous def'n: " );
		tprint( stp );
		printf( ", %s, (%d,%d) ), level %d\n", scnames(p->sclass), p->dimoff, p->sizoff, slev );
		}
# endif

	if( stp == FTN && p->sclass == SNULL )goto enter;
		/* name encountered as function, not yet defined */
		/* BUG here!  can't incompatibly declare func. in inner block */
	if( stp == UNDEF|| stp == FARG ){
		if( blevel==1 && stp!=FARG ) switch( class ){

		default:
			if(!(class&FIELD)) uerror( "declared argument %.8s is missing", p->sname );
		case MOS:
		case STNAME:
		case MOU:
		case UNAME:
		case MOE:
		case ENAME:
		case TYPEDEF:
			;
			}
		goto enter;
		}

	if( type != stp ) goto mismatch;
	/* test (and possibly adjust) dimensions */
	dsym = p->dimoff;
	ddef = q->fn.cdim;
	for( temp=type; temp&TMASK; temp = DECREF(temp) ){
		if( ISARY(temp) ){
			if( dimtab[dsym] == 0 ) dimtab[dsym] = dimtab[ddef];
			else if( dimtab[ddef]!=0 && dimtab[dsym] != dimtab[ddef] ){
				goto mismatch;
				}
			++dsym;
			++ddef;
			}
		}

	/* check that redeclarations are to the same structure */
	if( (temp==STRTY||temp==UNIONTY||temp==ENUMTY) && p->sizoff != q->fn.csiz
		 && class!=STNAME && class!=UNAME && class!=ENAME ){
		goto mismatch;
		}

	scl = ( p->sclass );

# ifndef BUG1
	if( ddebug ){
		printf( "	previous class: %s\n", scnames(scl) );
		}
# endif

	if( class&FIELD ){
		/* redefinition */
		if( !falloc( p, class&FLDSIZ, 1, NIL ) ) {
			/* successful allocation */
			psave( idp );
			return;
			}
		/* blew it: resume at end of switch... */
		}

	else switch( class ){

	case EXTERN:
		switch( scl ){
		case STATIC:
		case USTATIC:
			if( slev==0 ) return;
			break;
		case EXTDEF:
		case EXTERN:
		case FORTRAN:
		case UFORTRAN:
			return;
			}
		break;

	case STATIC:
		if( scl==USTATIC || (scl==EXTERN && blevel==0) ){
			p->sclass = STATIC;
			if( ISFTN(type) ) curftn = idp;
			return;
			}
		break;

	case USTATIC:
		if( scl==STATIC || scl==USTATIC ) return;
		break;

	case LABEL:
		if( scl == ULABEL ){
			p->sclass = LABEL;
			deflab( p->offset );
			return;
			}
		break;

	case TYPEDEF:
		if( scl == class ) return;
		break;

	case UFORTRAN:
		if( scl == UFORTRAN || scl == FORTRAN ) return;
		break;

	case FORTRAN:
		if( scl == UFORTRAN ){
			p->sclass = FORTRAN;
			if( ISFTN(type) ) curftn = idp;
			return;
			}
		break;

	case MOU:
	case MOS:
		if( scl == class ) {
			if( oalloc( p, &strucoff ) ) break;
			if( class == MOU ) strucoff = 0;
			psave( idp );
			return;
			}
		break;

	case MOE:
		if( scl == class ){
			if( p->offset!= strucoff++ ) break;
			psave( idp );
			}
		break;

	case EXTDEF:
		if( scl == EXTERN ) {
			p->sclass = EXTDEF;
			if( ISFTN(type) ) curftn = idp;
			return;
			}
		break;

	case STNAME:
	case UNAME:
	case ENAME:
		if( scl != class ) break;
		if( dimtab[p->sizoff] == 0 ) return;  /* previous entry just a mention */
		break;

	case ULABEL:
		if( scl == LABEL || scl == ULABEL ) return;
	case PARAM:
	case AUTO:
	case REGISTER:
		;  /* mismatch.. */

		}

	mismatch:
	/* allow nonunique structure/union member names */

	if( class==MOU || class==MOS || class & FIELD ){/* make a new entry */
		int * memp;
		p->sflags |= SNONUNIQ;  /* old entry is nonunique */
		/* determine if name has occurred in this structure/union */
		for( memp = &paramstk[paramno-1];
			/* while */ *memp>=0 && stab[*memp].sclass != STNAME
				&& stab[*memp].sclass != UNAME;
			/* iterate */ --memp){ char * cname, * oname;
			if( stab[*memp].sflags & SNONUNIQ ){int k;
				cname=p->sname;
				oname=stab[*memp].sname;
				for(k=1; k<=NCHNAM; ++k){
					if(*cname++ != *oname)goto diff;
					if(!*oname++)break;
					}
				uerror("redeclaration of: %s",p->sname);
				break;
				diff: continue;
				}
			}
		p = mknonuniq( &idp ); /* update p and idp to new entry */
		goto enter;
		}
	if( blevel > slev && class != EXTERN && class != FORTRAN &&
		class != UFORTRAN && !( class == LABEL && slev >= 2 ) ){
		q->tn.rval = idp = hide( p );
		p = &stab[idp];
		goto enter;
		}
	uerror( "redeclaration of %.8s", p->sname );
	if( class==EXTDEF && ISFTN(type) ) curftn = idp;
	return;

	enter:  /* make a new entry */

# ifndef BUG1
	if( ddebug ) printf( "	new entry made\n" );
# endif
	if( type == UNDEF ) uerror("void type for %.8s",p->sname);
	p->stype = type;
	p->sclass = class;
	p->slevel = blevel;
	p->offset = NOOFFSET;
	p->suse = lineno;
	if( class == STNAME || class == UNAME || class == ENAME ) {
		p->sizoff = curdim;
		dstash( 0 );  /* size */
		dstash( -1 ); /* index to members of str or union */
		dstash( ALSTRUCT );  /* alignment */
		dstash( idp );  /* name index */
		}
	else {
		switch( BTYPE(type) ){
		case STRTY:
		case UNIONTY:
		case ENUMTY:
			p->sizoff = q->fn.csiz;
			break;
		default:
			p->sizoff = BTYPE(type);
			}
		}

	/* copy dimensions */

	p->dimoff = q->fn.cdim;

	/* allocate offsets */
	if( class&FIELD ){
		falloc( p, class&FLDSIZ, 0, NIL );  /* new entry */
		psave( idp );
		}
	else switch( class ){

	case AUTO:
		oalloc( p, &autooff );
		break;
	case STATIC:
	case EXTDEF:
		p->offset = getlab();
		if( ISFTN(type) ) curftn = idp;
		break;
	case ULABEL:
	case LABEL:
		p->offset = getlab();
		p->slevel = 2;
		if( class == LABEL ){
			locctr( PROG );
			deflab( p->offset );
			}
		break;

	case EXTERN:
	case UFORTRAN:
	case FORTRAN:
		p->offset = getlab();
		p->slevel = 0;
		break;
	case MOU:
	case MOS:
		oalloc( p, &strucoff );
		if( class == MOU ) strucoff = 0;
		psave( idp );
		break;

	case MOE:
		p->offset = strucoff++;
		psave( idp );
		break;
	case REGISTER:
		p->offset = regvar--;
		if( blevel == 1 ) p->sflags |= SSET;
		if( regvar < minrvar ) minrvar = regvar;
		break;
		}

	/* user-supplied routine to fix up new definitions */

	FIXDEF(p);

# ifndef BUG1
	if( ddebug ) printf( "	dimoff, sizoff, offset: %d, %d, %d\n", p->dimoff, p->sizoff, p->offset );
# endif

	}

psave( i ){
	if( paramno >= PARAMSZ ){
		cerror( "parameter stack overflow");
		}
	paramstk[ paramno++ ] = i;
	}

ftnend(){ /* end of function */
	if( retlab != NOLAB ){ /* inside a real function */
		efcode();
		}
	checkst(0);
	retstat = 0;
	tcheck();
	curclass = SNULL;
	brklab = contlab = retlab = NOLAB;
	flostat = 0;
	if( nerrors == 0 ){
		if( psavbc != & asavbc[0] ) cerror("bcsave error");
		if( paramno != 0 ) cerror("parameter reset error");
		if( swx != 0 ) cerror( "switch error");
		}
	psavbc = &asavbc[0];
	paramno = 0;
	autooff = AUTOINIT;
	minrvar = regvar = MAXRVAR;
	reached = 1;
	swx = 0;
	swp = swtab;
	locctr(DATA);
	}

dclargs(){
	register i, j;
	register struct symtab *p;
	register NODE *q;
	argoff = ARGINIT;
# ifndef BUG1
	if( ddebug > 2) printf("dclargs()\n");
# endif
	for( i=0; i<paramno; ++i ){
		if( (j = paramstk[i]) < 0 ) continue;
		p = &stab[j];
# ifndef BUG1
		if( ddebug > 2 ){
			printf("\t%.8s (%d) ",p->sname, j);
			tprint(p->stype);
			printf("\n");
			}
# endif
		if( p->stype == FARG ) {
			q = block(FREE,NIL,NIL,INT,0,INT);
			q->tn.rval = j;
			defid( q, PARAM );
			}
		oalloc( p, &argoff );  /* always set aside space, even for register arguments */
		FIXARG(p); /* local arg hook, eg. for sym. debugger */
		}
	cendarg();
	locctr(PROG);
	defalign(ALINT);
	++ftnno;
	bfcode( paramstk, paramno );
	paramno = 0;
	}

NODE *
rstruct( idn, soru ){ /* reference to a structure or union, with no definition */
	register struct symtab *p;
	register NODE *q;
	p = &stab[idn];
	switch( p->stype ){

	case UNDEF:
	def:
		q = block( FREE, NIL, NIL, 0, 0, 0 );
		q->tn.rval = idn;
		q->in.type = (soru&INSTRUCT) ? STRTY : ( (soru&INUNION) ? UNIONTY : ENUMTY );
		defid( q, (soru&INSTRUCT) ? STNAME : ( (soru&INUNION) ? UNAME : ENAME ) );
		break;

	case STRTY:
		if( soru & INSTRUCT ) break;
		goto def;

	case UNIONTY:
		if( soru & INUNION ) break;
		goto def;

	case ENUMTY:
		if( !(soru&(INUNION|INSTRUCT)) ) break;
		goto def;

		}
	stwart = instruct;
	return( mkty( p->stype, 0, p->sizoff ) );
	}

moedef( idn ){
	register NODE *q;

	q = block( FREE, NIL, NIL, MOETY, 0, 0 );
	q->tn.rval = idn;
	if( idn>=0 ) defid( q, MOE );
	}

bstruct( idn, soru ){ /* begining of structure or union declaration */
	register NODE *q;

	psave( instruct );
	psave( curclass );
	psave( strucoff );
	strucoff = 0;
	instruct = soru;
	q = block( FREE, NIL, NIL, 0, 0, 0 );
	q->tn.rval = idn;
	if( instruct==INSTRUCT ){
		curclass = MOS;
		q->in.type = STRTY;
		if( idn >= 0 ) defid( q, STNAME );
		}
	else if( instruct == INUNION ) {
		curclass = MOU;
		q->in.type = UNIONTY;
		if( idn >= 0 ) defid( q, UNAME );
		}
	else { /* enum */
		curclass = MOE;
		q->in.type = ENUMTY;
		if( idn >= 0 ) defid( q, ENAME );
		}
	psave( idn = q->tn.rval );
	/* the "real" definition is where the members are seen */
	if( idn >= 0 ) stab[idn].suse = lineno;
	return( paramno-4 );
	}

NODE *
dclstruct( oparam ){
	register struct symtab *p;
	register i, al, sa, j, sz, szindex;
	register TWORD temp;
	register high, low;

	/* paramstack contains:
		paramstack[ oparam ] = previous instruct
		paramstack[ oparam+1 ] = previous class
		paramstk[ oparam+2 ] = previous strucoff
		paramstk[ oparam+3 ] = structure name

		paramstk[ oparam+4, ... ]  = member stab indices

		*/


	if( (i=paramstk[oparam+3]) < 0 ){
		szindex = curdim;
		dstash( 0 );  /* size */
		dstash( -1 );  /* index to member names */
		dstash( ALSTRUCT );  /* alignment */
		dstash( -lineno );  /* name of structure */
		}
	else {
		szindex = stab[i].sizoff;
		}

# ifndef BUG1
	if( ddebug ){
		printf( "dclstruct( %.8s ), szindex = %d\n", (i>=0)? stab[i].sname : "??", szindex );
		}
# endif
	temp = (instruct&INSTRUCT)?STRTY:((instruct&INUNION)?UNIONTY:ENUMTY);
	stwart = instruct = paramstk[ oparam ];
	curclass = paramstk[ oparam+1 ];
	dimtab[ szindex+1 ] = curdim;
	al = ALSTRUCT;

	high = low = 0;

	for( i = oparam+4;  i< paramno; ++i ){
		dstash( j=paramstk[i] );
		if( j<0 || j>= SYMTSZ ) cerror( "gummy structure member" );
		p = &stab[j];
		if( temp == ENUMTY ){
			if( p->offset < low ) low = p->offset;
			if( p->offset > high ) high = p->offset;
			p->sizoff = szindex;
			continue;
			}
		sa = talign( p->stype, p->sizoff );
		if( p->sclass & FIELD ){
			sz = p->sclass&FLDSIZ;
			}
		else {
			sz = tsize( p->stype, p->dimoff, p->sizoff );
			}
		if( sz == 0 ){
			uerror( "illegal zero sized structure member: %.8s", p->sname );
			}
		if( sz > strucoff ) strucoff = sz;  /* for use with unions */
		SETOFF( al, sa );
		/* set al, the alignment, to the lcm of the alignments of the members */
		}
	dstash( -1 );  /* endmarker */
	SETOFF( strucoff, al );

	if( temp == ENUMTY ){
		register TWORD ty;

# ifdef ENUMSIZE
		ty = ENUMSIZE(high,low);
# else
		if( (char)high == high && (char)low == low ) ty = ctype( CHAR );
		else if( (short)high == high && (short)low == low ) ty = ctype( SHORT );
		else ty = ctype(INT);
#endif
		strucoff = tsize( ty, 0, (int)ty );
		dimtab[ szindex+2 ] = al = talign( ty, (int)ty );
		}

	if( strucoff == 0 ) uerror( "zero sized structure" );
	dimtab[ szindex ] = strucoff;
	dimtab[ szindex+2 ] = al;
	dimtab[ szindex+3 ] = paramstk[ oparam+3 ];  /* name index */

	FIXSTRUCT( szindex, oparam ); /* local hook, eg. for sym debugger */
# ifndef BUG1
	if( ddebug>1 ){
		printf( "\tdimtab[%d,%d,%d,%d] = %d,%d,%d,%d\n",
			szindex,szindex+1,szindex+2,szindex+3,
			dimtab[szindex],dimtab[szindex+1],dimtab[szindex+2],
			dimtab[szindex+3] );
		for( i = dimtab[szindex+1]; dimtab[i] >= 0; ++i ){
			printf( "\tmember %.8s(%d)\n", stab[dimtab[i]].sname, dimtab[i] );
			}
		}
# endif

	strucoff = paramstk[ oparam+2 ];
	paramno = oparam;

	return( mkty( temp, 0, szindex ) );
	}

	/* VARARGS */
yyerror( s ) char *s; { /* error printing routine in parser */

	uerror( s );

	}

yyaccpt(){
	ftnend();
	}

ftnarg( idn ) {
	switch( stab[idn].stype ){

	case UNDEF:
		/* this parameter, entered at scan */
		break;
	case FARG:
		uerror("redeclaration of formal parameter, %.8s",
			stab[idn].sname);
		/* fall thru */
	case FTN:
		/* the name of this function matches parm */
		/* fall thru */
	default:
		idn = hide( &stab[idn]);
		break;
	case TNULL:
		/* unused entry, fill it */
		;
		}
	stab[idn].stype = FARG;
	stab[idn].sclass = PARAM;
	psave( idn );
	}


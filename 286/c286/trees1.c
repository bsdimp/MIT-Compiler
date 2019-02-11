# include "mfile1"

	    /* corrections when in violation of lint */

/*	some special actions, used in finding the type of nodes */
# define NCVT 01
# define PUN 02
# define TYPL 04
# define TYPR 010
# define TYMATCH 040
# define LVAL 0100
# define CVTO 0200
# define CVTL 0400
# define CVTR 01000
# define PTMATCH 02000
# define OTHER 04000
# define NCVTR 010000

/* node conventions:

	NAME:	rval>0 is stab index for external
		rval<0 is -inlabel number
		lval is offset in bits
	ICON:	lval has the value
		rval has the STAB index, or - label number,
			if a name whose address is in the constant
		rval = NONAME means no name
	REG:	rval is reg. identification cookie

	*/

int bdebug = 0;
extern ddebug;

NODE *
buildtree( o, l, r ) register NODE *l, *r; {
	register NODE *p, *q;
	register actions;
	register opty;
	register struct symtab *sp;
	register NODE *lr, *ll;
	int i;
	extern int eprint();

# ifndef BUG1
	if( bdebug ) printf( "buildtree( %s, %o, %o )\n", opst[o], l, r );
# endif
	opty = optype(o);

	/* check for constants */

	if( opty == UTYPE && l->in.op == ICON ){

		switch( o ){

		case NOT:
			if( hflag ) werror( "constant argument to NOT" );
		case UNARY MINUS:
		case COMPL:
			if( conval( l, o, l ) ) return(l);
			break;

			}
		}

	else if( o==UNARY MINUS && l->in.op==FCON ){
		l->fpn.dval = -l->fpn.dval;
		return(l);
		}

	else if( o==QUEST && l->in.op==ICON ) {
		l->in.op = FREE;
		r->in.op = FREE;
		if( l->tn.lval ){
			tfree( r->in.right );
			return( r->in.left );
			}
		else {
			tfree( r->in.left );
			return( r->in.right );
			}
		}

	else if( (o==ANDAND || o==OROR) && (l->in.op==ICON||r->in.op==ICON) ) goto ccwarn;

	else if( opty == BITYPE && l->in.op == ICON && r->in.op == ICON ){

		switch( o ){

		case ULT:
		case UGT:
		case ULE:
		case UGE:
		case LT:
		case GT:
		case LE:
		case GE:
		case EQ:
		case NE:
		case ANDAND:
		case OROR:
		case CBRANCH:

		ccwarn:
			if( hflag ) werror( "constant in conditional context" );

		case PLUS:
		case MINUS:
		case MUL:
		case DIV:
		case MOD:
		case AND:
		case OR:
		case ER:
		case LS:
		case RS:
			if( conval( l, o, r ) ) {
				r->in.op = FREE;
				return(l);
				}
			break;
			}
		}

	else if( opty == BITYPE && (l->in.op==FCON||l->in.op==ICON) &&
		(r->in.op==FCON||r->in.op==ICON) ){
		switch(o){
		case PLUS:
		case MINUS:
		case MUL:
		case DIV:
			if( l->in.op == ICON ){
				l->fpn.dval = l->tn.lval;
				}
			if( r->in.op == ICON ){
				r->fpn.dval = r->tn.lval;
				}
			l->in.op = FCON;
			l->in.type = l->fn.csiz = DOUBLE;
			r->in.op = FREE;
			switch(o){
			case PLUS:
				l->fpn.dval += r->fpn.dval;
				return(l);
			case MINUS:
				l->fpn.dval -= r->fpn.dval;
				return(l);
			case MUL:
				l->fpn.dval *= r->fpn.dval;
				return(l);
			case DIV:
				if( r->fpn.dval == 0 ) uerror( "division by 0." );
				else l->fpn.dval /= r->fpn.dval;
				return(l);
				}
			}
		}

	/* its real; we must make a new node */

	p = block( o, l, r, INT, 0, INT );

	actions = opact(p);

	if( actions&LVAL ){ /* check left descendent */
		if( notlval(p->in.left) ) {
			uerror( "illegal lhs of assignment operator" );
			}
		}

	if( actions & NCVTR ){
		p->in.left = pconvert( p->in.left );
		}
	else if( !(actions & NCVT ) ){
		switch( opty ){

		case BITYPE:
			p->in.right = pconvert( p->in.right );
		case UTYPE:
			p->in.left = pconvert( p->in.left );

			}
		}

	if( (actions&PUN) && (o!=CAST||cflag) ){
		chkpun(p);
		}

	if( actions & (TYPL|TYPR) ){

		q = (actions&TYPL) ? p->in.left : p->in.right;

		p->in.type = q->in.type;
		p->fn.cdim = q->fn.cdim;
		p->fn.csiz = q->fn.csiz;
		}

	if( actions & CVTL ) p = convert( p, CVTL );
	if( actions & CVTR ) p = convert( p, CVTR );
	if( actions & TYMATCH ) p = tymatch(p);
	if( actions & PTMATCH ) p = ptmatch(p);

	if( actions & OTHER ){
		l = p->in.left;
		r = p->in.right;

		switch(o){

		case NAME:
			sp = &stab[idname];
			if( sp->stype == UNDEF ){
				uerror( "%.8s undefined", sp->sname );
				/* make p look reasonable */
				p->in.type = p->fn.cdim = p->fn.csiz = INT;
				p->tn.rval = idname;
				p->tn.lval = 0;
				defid( p, SNULL );
				break;
				}
			p->in.type = sp->stype;
			p->fn.cdim = sp->dimoff;
			p->fn.csiz = sp->sizoff;
			p->tn.lval = 0;
			p->tn.rval = idname;
			/* special case: MOETY is really an ICON... */
			if( p->in.type == MOETY ){
				p->tn.rval = NONAME;
				p->tn.lval = sp->offset;
				p->fn.cdim = 0;
				p->in.type = ENUMTY;
				p->in.op = ICON;
				}
			break;

		case ICON:
			p->in.type = INT;
			p->fn.cdim = 0;
			p->fn.csiz = INT;
			break;

		case STRING:
			p->in.op = NAME;
			p->in.type = CHAR+ARY;
			p->tn.lval = 0;
			p->tn.rval = NOLAB;
			p->fn.cdim = curdim;
			p->fn.csiz = CHAR;
			break;

		case FCON:
			p->tn.lval = 0;
			p->tn.rval = 0;
			p->in.type = DOUBLE;
			p->fn.cdim = 0;
			p->fn.csiz = DOUBLE;
			break;

		case STREF:
			/* p->x turned into *(p+offset) */
			/* rhs must be a name; check correctness */

			i = r->tn.rval;
			if( i<0 || ((sp= &stab[i])->sclass != MOS && sp->sclass != MOU && !(sp->sclass&FIELD)) ){
				uerror( "member of structure or union required" );
				}else
			/* if this name is non-unique, find right one */
			if( stab[i].sflags & SNONUNIQ &&
				(l->in.type==PTR+STRTY || l->in.type == PTR+UNIONTY) &&
				(l->fn.csiz +1) >= 0 ){
				/* nonunique name && structure defined */
				char * memnam, * tabnam;
				register k;
				int j;
				int memi;
				j=dimtab[l->fn.csiz+1];
				for( ; (memi=dimtab[j]) >= 0; ++j ){
					tabnam = stab[memi].sname;
					memnam = stab[i].sname;
# ifndef BUG1
					if( ddebug>1 ){
						printf("member %.8s==%.8s?\n",
							memnam, tabnam);
						}
# endif
					if( stab[memi].sflags & SNONUNIQ ){
						for( k=0; k<NCHNAM; ++k ){
							if(*memnam++!=*tabnam)
								goto next;
							if(!*tabnam++) break;
							}
						r->tn.rval = i = memi;
						break;
						}
					next: continue;
					}
				if( memi < 0 )
					uerror("illegal member use: %.8s",
						stab[i].sname);
				}
			else {
				register j;
				if( l->in.type != PTR+STRTY && l->in.type != PTR+UNIONTY ){
					if( stab[i].sflags & SNONUNIQ ){
						uerror( "nonunique name demands struct/union or struct/union pointer" );
						}
					else werror( "struct/union or struct/union pointer required" );
					}
				else if( (j=l->fn.csiz+1)<0 ) cerror( "undefined structure or union" );
				else if( !chkstr( i, dimtab[j], DECREF(l->in.type) ) ){
					werror( "illegal member use: %.8s", stab[i].sname );
					}
				}

			p = stref( p );
			break;

		case UNARY MUL:
			if( l->in.op == UNARY AND ){
				p->in.op = l->in.op = FREE;
				p = l->in.left;
				}
			if( !ISPTR(l->in.type))uerror("illegal indirection");
			p->in.type = DECREF(l->in.type);
			p->fn.cdim = l->fn.cdim;
			p->fn.csiz = l->fn.csiz;
			break;

		case UNARY AND:
			switch( l->in.op ){

			case UNARY MUL:
				p->in.op = l->in.op = FREE;
				p = l->in.left;
			case NAME:
				p->in.type = INCREF( l->in.type );
				p->fn.cdim = l->fn.cdim;
				p->fn.csiz = l->fn.csiz;
				break;

			case COMOP:
				lr = buildtree( UNARY AND, l->in.right, NIL );
				p->in.op = l->in.op = FREE;
				p = buildtree( COMOP, l->in.left, lr );
				break;

			case QUEST:
				lr = buildtree( UNARY AND, l->in.right->in.right, NIL );
				ll = buildtree( UNARY AND, l->in.right->in.left, NIL );
				p->in.op = l->in.op = l->in.right->in.op = FREE;
				p = buildtree( QUEST, l->in.left, buildtree( COLON, ll, lr ) );
				break;

# ifdef ADDROREG
			case OREG:
				/* OREG was built in clocal()
				 * for an auto or formal parameter
				 * now its address is being taken
				 * local code must unwind it
				 * back to PLUS/MINUS REG ICON
				 * according to local conventions
				 */
				{
				extern NODE * addroreg();
				p->in.op = FREE;
				p = addroreg( l );
				}
				break;

# endif
			default:
				uerror( "unacceptable operand of &" );
				break;
				}
			break;

		case LS:
		case RS:
		case ASG LS:
		case ASG RS:
			if(tsize(p->in.right->in.type, p->in.right->fn.cdim, p->in.right->fn.csiz) > SZINT)
				p->in.right = makety(p->in.right, INT, 0, INT );
			break;

		case RETURN:
		case ASSIGN:
		case CAST:
			/* structure assignment */
			/* take the addresses of the two sides; then make an
			/* operator using STASG and
			/* the addresses of left and right */

			{
				register TWORD t;
				register d, s;

				if( l->fn.csiz != r->fn.csiz ) uerror( "assignment of different structures" );

				r = buildtree( UNARY AND, r, NIL );
				t = r->in.type;
				d = r->fn.cdim;
				s = r->fn.csiz;

				l = block( STASG, l, r, t, d, s );

				if( o == RETURN ){
					p->in.op = FREE;
					p = l;
					break;
					}

				p->in.op = UNARY MUL;
				p->in.left = l;
				p->in.right = NIL;
				break;
				}
		case COLON:
			/* structure colon */

			if( l->fn.csiz != r->fn.csiz ) uerror( "type clash in conditional" );
			break;

		case CALL:
			p->in.right = r = strargs( p->in.right );
		case UNARY CALL:
			if( !ISPTR(l->in.type)) uerror("illegal function");
			p->in.type = DECREF(l->in.type);
			if( !ISFTN(p->in.type)) uerror("illegal function");
			p->in.type = DECREF( p->in.type );
			p->fn.cdim = l->fn.cdim;
			p->fn.csiz = l->fn.csiz;
			if( l->in.op == UNARY AND && l->in.left->in.op == NAME &&
				l->in.left->tn.rval >= 0 && l->in.left->tn.rval != NONAME &&
				( (i=stab[l->in.left->tn.rval].sclass) == FORTRAN || i==UFORTRAN ) ){
				p->in.op += (FORTCALL-CALL);
				}
			if( p->in.type == STRTY || p->in.type == UNIONTY ){
				/* function returning structure */
				/*  make function really return ptr to str., with * */

				p->in.op += STCALL-CALL;
				p->in.type = INCREF( p->in.type );
				p = buildtree( UNARY MUL, p, NIL );

				}
			break;

		default:
			cerror( "other code %d", o );
			}

		}

	if( actions & CVTO ) p = oconvert(p);
	p = clocal(p);

# ifndef BUG1
	if( bdebug ) fwalk( p, eprint, 0 );
# endif

	return(p);

	}

NODE *
strargs( p ) register NODE *p;  { /* rewrite structure flavored arguments */

	if( p->in.op == CM ){
		p->in.left = strargs( p->in.left );
		p->in.right = strargs( p->in.right );
		return( p );
		}

	if( p->in.type == STRTY || p->in.type == UNIONTY ){
		p = block( STARG, p, NIL, p->in.type, p->fn.cdim, p->fn.csiz );
		p->in.left = buildtree( UNARY AND, p->in.left, NIL );
		p = clocal(p);
		}
	return( p );
	}

chkstr( i, j, type ) TWORD type; {
	/* is the MOS or MOU at stab[i] OK for strict reference by a ptr */
	/* i has been checked to contain a MOS or MOU */
	/* j is the index in dimtab of the members... */
	int k, kk;

	extern int ddebug;

# ifndef BUG1
	if( ddebug > 1 ) printf( "chkstr( %.8s(%d), %d )\n", stab[i].sname, i, j );
# endif
	if( (k = j) < 0 ) uerror( "undefined structure or union" );
	else {
		for( ; (kk = dimtab[k] ) >= 0; ++k ){
			if( kk >= SYMTSZ ){
				cerror( "gummy structure" );
				return(1);
				}
			if( kk == i ) return( 1 );
			switch( stab[kk].stype ){

			case STRTY:
			case UNIONTY:
				if( type == STRTY ) continue;  /* no recursive looking for strs */
				if( hflag && chkstr( i, dimtab[stab[kk].sizoff+1], stab[kk].stype ) ){
					if( stab[kk].sname[0] == '$' ) return(0);  /* $FAKE */
					werror(
					"illegal member use: perhaps %.8s.%.8s?",
					stab[kk].sname, stab[i].sname );
					return(1);
					}
				}
			}
		}
	return( 0 );
	}

conval( p, o, q ) register NODE *p, *q; {
	/* apply the op o to the lval part of p; if binary, rhs is val */
	int i, u;
	CONSZ val;

	val = q->tn.lval;
	u = ISUNSIGNED(p->in.type) || ISUNSIGNED(q->in.type);
	if( u && (o==LE||o==LT||o==GE||o==GT)) o += (UGE-GE);

	if( p->tn.rval != NONAME && q->tn.rval != NONAME ) return(0);
	if( q->tn.rval != NONAME && o!=PLUS ) return(0);
	if( p->tn.rval != NONAME && o!=PLUS && o!=MINUS ) return(0);

	switch( o ){

	case PLUS:
		p->tn.lval += val;
		if( p->tn.rval == NONAME ){
			p->tn.rval = q->tn.rval;
			p->in.type = q->in.type;
			}
		break;
	case MINUS:
		p->tn.lval -= val;
		break;
	case MUL:
		p->tn.lval *= val;
		break;
	case DIV:
		if( val == 0 ) uerror( "division by 0" );
		else p->tn.lval /= val;
		break;
	case MOD:
		if( val == 0 ) uerror( "division by 0" );
		else p->tn.lval %= val;
		break;
	case AND:
		p->tn.lval &= val;
		break;
	case OR:
		p->tn.lval |= val;
		break;
	case ER:
		p->tn.lval ^=  val;
		break;
	case LS:
		i = val;
		p->tn.lval = p->tn.lval << i;
		break;
	case RS:
		i = val;
		p->tn.lval = p->tn.lval >> i;
		break;

	case UNARY MINUS:
		p->tn.lval = - p->tn.lval;
		break;
	case COMPL:
		p->tn.lval = ~p->tn.lval;
		break;
	case NOT:
		p->tn.lval = !p->tn.lval;
		break;
	case LT:
		p->tn.lval = p->tn.lval < val;
		break;
	case LE:
		p->tn.lval = p->tn.lval <= val;
		break;
	case GT:
		p->tn.lval = p->tn.lval > val;
		break;
	case GE:
		p->tn.lval = p->tn.lval >= val;
		break;
	case ULT:
		p->tn.lval = (p->tn.lval-val)<0;
		break;
	case ULE:
		p->tn.lval = (p->tn.lval-val)<=0;
		break;
	case UGE:
		p->tn.lval = (p->tn.lval-val)>=0;
		break;
	case UGT:
		p->tn.lval = (p->tn.lval-val)>0;
		break;
	case EQ:
		p->tn.lval = p->tn.lval == val;
		break;
	case NE:
		p->tn.lval = p->tn.lval != val;
		break;
	default:
		return(0);
		}
	return(1);
	}


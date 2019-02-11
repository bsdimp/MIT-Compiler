
/*
 * C object code improver-- second part
 */

#include "o68.h"

rmove()
{
	register struct node *p;
	register char *cp;
	register int r;
	int r1;
	struct node *ptemp;

	for (p=first.forw; p!=0; p = p->forw) {
	if (debug) {
		for (r=0; r<NREG; r++)
			if (regs[r][0])
				printf("%d: %s ", r, regs[r]);
		printf("-\n");
	}

	switch (p->op) {

	case MOVEQ:
	case MOV:
		if (p->subop==BYTE || p->subop==WORD)
			goto badmov;
		dualop(p);
		if ((r = findrand(regs[RT1])) >= 0) {
			if (r == isreg(regs[RT2]) && p->forw->op!=CBR) {
				p->forw->back = p->back;
				p->back->forw = p->forw;
				p->ref = freenodes;
				freenodes = p;
				redunm++;
				continue;
			}
		}
		repladdr(p, 0, 1);
		r = isreg(regs[RT1]);
		r1 = isreg(regs[RT2]);
		dest(regs[RT2]);
		if (r >= 0)
			if (r1 >= 0)
				savereg(r1, regs[r]);
			else
				savereg(r, regs[RT2]);
		else
			if (r1 >= 0)
				savereg(r1, regs[RT1]);
			else
				setcon(regs[RT1], regs[RT2]);
		source(regs[RT1]);
/*		setcc(regs[RT2]);
*/		continue;

	case MULS:
	case MULU:
	case DIVS:
	case DIVU:
	case ADD:
/*
	case ADDQ:
*/
	case SUB:
	case SUBQ:
	case AND:
	case OR:
	case EOR:
	badmov:
		dualop(p);
		repladdr(p, 0, 1);
		source(regs[RT1]);
		dest(regs[RT2]);
		ccloc[0] = 0;
		continue;

	case CLR:
	case NOT:
	case NEG:
	case EXT:
		singop(p);
		dest(regs[RT1]);
		if (p->op==CLR)
			if ((r = isreg(regs[RT1])) >= 0)
				savereg(r, "#0");
			else
				setcon("#0", regs[RT1]);
		ccloc[0] = 0;
		continue;

	case TST:
		singop(p);
		repladdr(p, 0, 0);
		source(regs[RT1]);
		if (regs[RT1][0] && equstr(regs[RT1], ccloc)) {
			p->back->forw = p->forw;
			p->forw->back = p->back;
			ptemp = p;
			p = p->back;
			ptemp->ref = freenodes;
			freenodes = ptemp;
			nrtst++;
			nchange++;
		}
		continue;

	case CMP:
		dualop(p);
		source(regs[RT1]);
		source(regs[RT2]);
		repladdr(p, 1, 1);
		ccloc[0] = 0;
		continue;

	case CBR:
		ccloc[0] = 0;
		continue;

	case JBR:
		redunbr(p);

	default:
		clearreg();
	}
	}
}

jumpsw()
{
	register struct node *p, *p1;
	register t;
	int nj;

	t = 0;
	nj = 0;
	for (p=first.forw; p!=0; p = p->forw)
		p->refc = ++t;
	for (p=first.forw; p!=0; p = p1) {
		p1 = p->forw;
		if (p->op == CBR && p1->op==JBR && p->ref && p1->ref
		 && abs(p->refc - p->ref->refc) > abs(p1->refc - p1->ref->refc)) {
			struct node *nt;
			if (p->ref==p1->ref)
				continue;
			p->subop = revbr[p->subop];
			nt = p1->ref;
			p1->ref = p->ref;
			p->ref = nt;
			t = p1->labno;
			p1->labno = p->labno;
			p->labno = t;
			nrevbr++;
			nj++;
		}
	}
	return(nj);
}

abs(x)
{
	return(x<0? -x: x);
}

equop(ap1, p2)
struct node *ap1, *p2;
{
	register char *cp1, *cp2;
	register struct node *p1;

	p1 = ap1;
	if (p1->op!=p2->op || p1->subop!=p2->subop)
		return(0);
	if (p1->op>0 && p1->op<MOV)
		return(0);
	cp1 = p1->code;
	cp2 = p2->code;
	if (cp1==0 && cp2==0)
		return(1);
	if (cp1==0 || cp2==0)
		return(0);
	while (*cp1 == *cp2++)
		if (*cp1++ == 0)
			return(1);
	return(0);
}

decref(ap)
struct node *ap;
{
	register struct node *p;

	p = ap;
	if (p->op != LABEL) return;
	if (--p->refc <= 0) {
		nrlab++;
		p->back->forw = p->forw;
		p->forw->back = p->back;
		p->ref = freenodes;
		freenodes = p;
	}
}

struct node *
nonlab(ap)
struct node *ap;
{
	register struct node *p;

	p = ap;
	while (p && p->op==LABEL)
		p = p->forw;
	return(p);
}

struct node *
getnode()
  {	register struct node *p;

	if (p = freenodes) { freenodes = p->ref; p->subop = 0; return(p); }
	return ((struct node *) calloc(1,sizeof first));
}

clearreg()
{
	register int i;

	for (i=0; i<NREG; i++)
		regs[i][0] = '\0';
	conloc[0] = 0;
	ccloc[0] = 0;
}

savereg(ai, as)
char *as;
{
	register char *p, *s, *sp;

	sp = p = regs[ai];
	s = as;
	if (source(s))
		return;
/*	if (s[0]=='a' && s[1]<'6' && s[2]=='@') {
 *		*sp = 0;
 *		return;
 *	}
 */	while (*p++ = *s) {
		if (*s++ == ',')
			break;
	}
	*--p = '\0';
}

/* look through register contents table, clearing entries based on value
 * of address register n (n passed as arg).
 */
areg(reg)
  {	register int i;
	register char *p;

	for (i = 0; i < RT2; i++) {
	  p = regs[i];
	  if (*p++ == 'a' && *p == (reg - 8 + '0')) regs[i][0] = 0;
	}
}

/* update register contents table assuming operand passed as argument
 * was affected by instruction
 */
dest(as)
char *as;
{
	register char *s;
	register int i;

	s = as;
	source(s);

	/* if dest was a register, update registers table entry */
	if ((i = isreg(s)) >= 0) regs[i][0] = 0;

	/* if dest was an address reg, clear table entries for regs that
	 * were loaded using that address reg.
	 */
	if (i >= 8) areg(i);

	/* clear any regs that claim to have copy of dest's value */
	while ((i = findrand(s)) >= 0) regs[i][0] = 0;

	/* if there is any indirection, we don't know anything afterward */
	if (*s++=='a' && *s>='0' && *s++<='5' && *s=='@') {
		for (i=0; i<NREG; i++) {
			if (regs[i][0] != '#') regs[i][0] = 0;
			conloc[0] = 0;
		}
	}
}

/* set RT1 (source) "register" from assy. language code */
singop(ap)
struct node *ap;
{
	register char *p1, *p2;

	p1 = ap->code;
	p2 = regs[RT1];
	while (*p2++ = *p1++);
	regs[RT2][0] = 0;
}


/* set RT1 (source) and RT2 (dest) "registers" from assy. language code */
dualop(ap)
struct node *ap;
{
	register char *p1, *p2;
	register struct node *p;

	p = ap;
	p1 = p->code;
	p2 = regs[RT1];
	while (*p1 && *p1!=',')
		*p2++ = *p1++;
	*p2++ = 0;
	p2 = regs[RT2];
	*p2 = 0;
	if (*p1++ !=',')
		return;
	while (*p1==' ' || *p1=='\t')
		p1++;
	while (*p2++ = *p1++);
}

/* return register number of reg that already contains operand passed as
 * arg, -1 otherwise.
 */
findrand(as)
char *as;
{	register int i;

	if (*as) for (i = 0; i<NREG; i++) {
		if (equstr(regs[i], as))
			return(i);
	}

	return(-1);
}

/* return register number if operand corresponds to register, else -1 */
isreg(as)
char *as;
{
	register char *s;

	s = as;
	if (s[0]=='d' && s[1]>='0' && s[1]<='7' && s[2]==0)
		return(s[1]-'0');
	if (s[0]=='a' && s[1]>='0' && s[1]<='5' && s[2]==0)
		return(s[1]-'0'+8);
	return(-1);
}

check()
{
	register struct node *p, *lp;

	lp = &first;
	for (p=first.forw; p!=0; p = p->forw) {
		if (p->back != lp)
			abort();
		lp = p;
	}
}

/* look for operands of the form an@+ or an@-; if found, reset register contents
 * table for register n and for any regs based on address register n.
 */
source(ap)
char *ap;
{
	register char *p1, *p2;
	register int i;

	p1 = ap;
	p2 = p1;
	if (*p1==0)
		return(0);
	while (*p2++);
	if (*(p2-2)=='+' || *(p2-2)=='-') {
		if (*p1++=='a' && *p1>='0' && *p1<='5') {
		  regs[(i = *p1 - '0' + 8)][0] = 0;
		  areg(i);
		}
		return(1);
	}
	return(0);
}

/* g <> 0 if address is ok as replacement */
repladdr(p, f, g)
struct node *p;
{
	register r;
	int r1;
	register char *p1, *p2;
	static char rt1[50], rt2[50];

	if (f)
		r1 = findrand(regs[RT2]);
	else
		r1 = -1;
	r = findrand(regs[RT1]);
	if (r>=0 || r1>=0) {
		p2 = regs[RT1];
		for (p1 = rt1; *p1++ = *p2++;);
		if (regs[RT2][0]) {
			p1 = rt2;
			*p1++ = ',';
			for (p2 = regs[RT2]; *p1++ = *p2++;);
		} else
			rt2[0] = 0;
		if (r>=0) {
			if (r>7) {
			  if (!g) return;
			  rt1[0] = 'a';
			  rt1[1] = r - 8 + '0';
			} else { rt1[0] = 'd'; rt1[1] = r + '0'; }
			rt1[2] = 0;
			nsaddr++;
		}
		if (r1>=0) {
			if (r1>7) {
			  if (!g) return;
			  rt2[1] = 'a';
			  rt2[2] = r1 - 8 + '0';
			} else { rt2[1] = 'd'; rt2[2] = r1 + '0'; }
			rt2[3] = 0;
			nsaddr++;
		}
		strcat(rt1,rt2);
		p->code = copy(rt1);
	}
}

movedat()
{
	register struct node *p1, *p2;
	struct node *p3;
	register seg;
	struct node data;
	struct node *datp;

	if (first.forw == 0)
		return;
/*	data.forw = 0;
	datp = &data;
	for (p1 = first.forw; p1!=0; p1 = p1->forw) {
		if (p1->op == DATA) {
			p2 = p1->forw;
			while (p2 && p2->op!=TEXT)
				p2 = p2->forw;
			if (p2==0)
				break;
			p3 = p1->back;
			p1->back->forw = p2->forw;
			p2->forw->back = p3;
			p2->forw = 0;
			datp->forw = p1;
			p1->back = datp;
			p1 = p3;
			datp = p2;
		}
	}
	if (data.forw) {
		datp->forw = first.forw;
		first.forw->back = datp;
		data.forw->back = &first;
		first.forw = data.forw;
	}
*/	seg = -1;
	for (p1 = first.forw; p1!=0; p1 = p1->forw) {
		if (p1->op==TEXT||p1->op==DATA||p1->op==BSS) {
			if (p1->op == seg ||
			    (p1->forw && (p1->forw->op==TEXT||p1->forw->op==DATA||p1->forw->op==BSS))) {
				p1->back->forw = p1->forw;
				p1->forw->back = p1->back;
				p1->ref = freenodes;
				freenodes = p1;
				p1 = p1->back;
				continue;
			}
			seg = p1->op;
		}
	}
}

redunbr(ap)
struct node *ap;
{
	register struct node *p, *p1;
	register char *ap1;
	char *ap2;

	if ((p1 = p->ref) == 0)
		return;
	p1 = nonlab(p1);
	if (p1->op==TST) {
		singop(p1);
		savereg(RT2, "#0");
	} else if (p1->op==CMP)
		dualop(p1);
	else
		return;
	if (p1->forw->op!=CBR)
		return;
	ap1 = findcon(RT1);
	ap2 = findcon(RT2);
	p1 = p1->forw;
	if (compare(p1->subop, ap1, ap2)) {
		nredunj++;
		nchange++;
		decref(p->ref);
		p->ref = p1->ref;
		p->labno = p1->labno;
		p->ref->refc++;
	}
}

char *
findcon(i)
{
	register char *p;
	register r;

	p = regs[i];
	if (*p=='#')
		return(p);
	if ((r = isreg(p)) >= 0)
		return(regs[r]);
	if (equstr(p, conloc))
		return(conval);
	return(p);
}

compare(op, acp1, acp2)
char *acp1, *acp2;
{
	register char *cp1, *cp2;
	register n1;
	int n2;
	struct { int i;};

	cp1 = acp1;
	cp2 = acp2;
	if (*cp1++ != '#' || *cp2++ != '#')
		return(0);
	n1 = 0;
	while (*cp2 >= '0' && *cp2 <= '9') {
		n1 *= 10;
		n1 += *cp2++ - '0';
	}
	n2 = n1;
	n1 = 0;
	while (*cp1 >= '0' && *cp1 <= '9') {
		n1 *= 10;
		n1 += *cp1++ - '0';
	}
	if (*cp1=='+')
		cp1++;
	if (*cp2=='+')
		cp2++;
	do {
		if (*cp1++ != *cp2)
			return(0);
	} while (*cp2++);
	switch(op) {

	case JEQ:
		return (n1 == n2);
	case JNE:
		return (n1 != n2);
	case JLE:
		return ((int) n1 <= (int) n2);
	case JGE:
		return ((int) n1 >= (int) n2);
	case JLT:
		return ((int) n1 >= (int) n2);
	case JGT:
		return ((int) n1 > (int) n2);
	case JLO:
		return ((unsigned) n1 < (unsigned) n2);
	case JHI:
		return ((unsigned) n1 > (unsigned) n2);
	case JLOS:
		return ((unsigned) n1 <= (unsigned) n2);
	case JHIS:
		return ((unsigned) n1 >= (unsigned) n2);
	}
	return(0);
}

setcon(ar1, ar2)
char *ar1, *ar2;
{
	register char *cl, *cv, *p;

	cl = ar2;
	cv = ar1;
	if (*cv != '#')
		return;
	if (!natural(cl))
		return;
	p = conloc;
	while (*p++ = *cl++);
	p = conval;
	while (*p++ = *cv++);
}

equstr(ap1, ap2)
char *ap1, *ap2;
{
	char *p1, *p2;

	p1 = ap1;
	p2 = ap2;
	do {
		if (*p1++ != *p2)
			return(0);
	} while (*p2++);
	return(1);
}

setcc(ap)
char *ap;
{
	register char *p, *p1;

	p = ap;
	if (!natural(p)) {
		ccloc[0] = 0;
		return;
	}
	p1 = ccloc;
	while (*p1++ = *p++);
}

natural(ap)
char *ap;
{
	register char *p;

	p = ap;
	if (*p=='*' || *p=='(' || *p=='-' && *(p+1)=='(')
		return(0);
	while (*p++);
	p--;
	if (*--p == '+' || *p ==')' && *--p != '5')
		return(0);
	return(1);
}

#
/*
 *	 C object code improver
 */

#include "o68.h"

extern struct node	*getnode();
extern struct node	*nonlab();
extern char	*calloc();

struct node	*codemove();
struct node	*insertl();
char	*copy();

struct optab optab[] = {
	"bra",	JBR,
	"beq",	CBR | JEQ<<8,
	"bne",	CBR | JNE<<8,
	"ble",	CBR | JLE<<8,
	"bge",	CBR | JGE<<8,
	"blt",	CBR | JLT<<8,
	"bgt",	CBR | JGT<<8,
	"bcs",	CBR | JLO<<8,
	"bhi",	CBR | JHI<<8,
	"bls",	CBR | JLOS<<8,
	"bcc",	CBR | JHIS<<8,
	"jmp",	JMP,
	".globl",EROU,
	".word",JSW,
	"mov",	MOV,
	"clr",	CLR,
	"not",	NOT,
	"addq",	ADDQ,
	"subq",	SUBQ,
	"neg",	NEG,
	"tst",	TST,
	"asr",	ASR,
	"asl",	ASL,
	"lsr",	LSR,
	"lsl",	LSL,
	"ext",	EXT,
	"cmp",	CMP,
	"add",	ADD,
	"sub",	SUB,
	"and",	AND,
	"or",	OR,
	"eor",	EOR,
	"muls",	MULS,
	"mulu",	MULU,
	"divs",	DIVS,
	"divu",	DIVU,
	"jsr",	JSR,
	"lea",	LEA,
	"pea",	PEA,
	"movem",MOVEM,
	"moveq",MOVEQ,
	"link",	LINK,
	"unlk",	UNLK,
	".text",TEXT,
	".data",DATA,
	".bss",	BSS,
	".even",EVEN,
	".end",	END,
	0,	0};

char	revbr[] = { JNE, JEQ, JGT, JLT, JGE, JLE, JHIS, JLOS, JHI, JLO };
int	isn	= 20000;

FILE *infile,*outfile;

main(argc, argv)
char **argv;
{
	register int niter, maxiter, isend;
	extern end;
	int nflag;

	if (argc>1 && argv[1][0]=='+') {
		argc--;
		argv++;
		debug++;
	}
	nflag = 0;
	if (argc>1 && argv[1][0]=='-') {
		argc--;
		argv++;
		nflag++;
	}
	if (argc>1) {
		if ((infile = fopen(argv[1], "r")) == NULL) {
			fprintf(stderr,"C2: can't find %s\n", argv[1]);
			exit(1);
		}
	} else
		infile = stdin;
	if (argc>2) {
		if ((outfile = fopen(argv[2], "w")) == NULL) {
			fprintf(stderr,"C2: can't create %s\n", argv[2]);
			exit(1);
		}
	} else
		outfile = stdout;

	freenodes = 0;
	maxiter = 0;
	opsetup();
	do {
		isend = input();
		movedat();
		nchange = niter = 0;
		do {
			refcount();
			do {
				if (debug) printf("iterate\n");
				iterate();
				clearreg();
				niter++;
			} while (nchange);
			if (debug) printf("comjump\n");
			comjump();
			if (debug) printf("rmove\n");
			rmove();
		} while (nchange || jumpsw());
		output();
		fflush(outfile);
		if (niter > maxiter)
			maxiter = niter;
	} while (isend);
	fflush(outfile);
	if (nflag) {
		fprintf(stderr,"%d iterations\n", maxiter);
		fprintf(stderr,"%d jumps to jumps\n", nbrbr);
		fprintf(stderr,"%d inst. after jumps\n", iaftbr);
		fprintf(stderr,"%d jumps to .+2\n", njp1);
		fprintf(stderr,"%d redundant labels\n", nrlab);
		fprintf(stderr,"%d cross-jumps\n", nxjump);
		fprintf(stderr,"%d code motions\n", ncmot);
		fprintf(stderr,"%d branches reversed\n", nrevbr);
		fprintf(stderr,"%d redundant moves\n", redunm);
		fprintf(stderr,"%d simplified addresses\n", nsaddr);
		fprintf(stderr,"%d loops inverted\n", loopiv);
		fprintf(stderr,"%d redundant jumps\n", nredunj);
		fprintf(stderr,"%d common seqs before jmp's\n", ncomj);
		fprintf(stderr,"%d skips over jumps\n", nskip);
		fprintf(stderr,"%d redundant tst's\n", nrtst);
		fflush(stderr);
	}
	exit(0);
}

input()
{
	register struct node *p, *lastp;
	register int op;
	int subop;

	lastp = &first;
	for (;;) {
		op = getline();
		subop = (op>>8)&0377;
		op &= 0377;
		switch (op) {
	
		case LABEL:
			p = getnode();
			if (line[0]=='.' && line[1]=='L') {
				p->labno = getnum(line+2);
				p->op = LABEL;
				p->code = 0;
			} else {
				p->op = DLABEL;
				p->labno = 0;
				p->code = copy(line);
			}
			break;
	
		case JSW:
			p = getnode();
			p->op = JSW;
			p->subop = 0;
			if (*curlp=='.' && *(curlp+1)=='L') {
			  p->labno = getnum(curlp+2);
			  while (*curlp && *curlp!='-') curlp++;
			  if (*curlp == 0) goto notjsw;
			  p->code = copy(curlp);
			  break;
			}
		notjsw:	p->op = p->labno = 0;
			p->code = copy(line);
			break;

		case JBR:
		case CBR:
		case JMP:
			p = getnode();
			p->op = op;
			p->subop = subop;
			if (*curlp=='.' && *(curlp+1)=='L') {
				p->labno = getnum(curlp+2);
				p->code = 0;
			} else if (*curlp=='p' && *(curlp+1)=='c' && *(curlp+2)=='@') {
				p->op = p->subop = p->labno = 0;
				p->code = copy(line);
			} else {
				p->labno = 0;
				p->code = copy(curlp);
			}
			break;

		default:
			p = getnode();
			p->op = op;
			p->subop = subop;
			p->labno = 0;
			p->code = copy(curlp);
			break;

		}
		p->forw = 0;
		p->back = lastp;
		lastp->forw = p;
		lastp = p;
		p->ref = 0;
		if (op==EROU)
			return(1);
		if (op==END)
			return(0);
	}
}

getline()
{
	register char *lp;
	register c;
	register ftab;

  again:
	lp = line;
	ftab = 0;
	while ((c = getc(infile)) != EOF) {
		if (!ftab && c==':') {
			*lp++ = 0;
			return(LABEL);
		}
		if (c=='\n') {
			if (lp==line) goto again;
			*lp++ = 0;
			return(oplook());
		}
		if (c=='\t') ftab++;
		*lp++ = c;
	}
	*lp++ = 0;
	return(END);
}

getnum(ap)
char *ap;
{
	register char *p;
	register n, c;

	p = ap;
	n = 0;
	while ((c = *p++) >= '0' && c <= '9')
		n = n*10 + c - '0';
	if (*--p!=0 && *p!='-')
		return(0);
	return(n);
}

output()
{
	register struct node *t;
	register struct optab *op;
	register int byte;
	struct node *temp;

	t = first.forw;
	while (t) {
	switch (t->op) {

	case END:
		return;

	case LABEL:
		fprintf(outfile,".L%d:\n", t->labno);
		break;

	case DLABEL:
		fprintf(outfile,"%s:\n", t->code);
		cfree(t->code);
		break;

	default:
		byte = t->subop;
		if (byte==BYTE || byte==WORD || byte==LONG) t->subop = 0;
		for (op = optab; op->opstring!=0; op++) 
			if (op->opcode == (t->op | (t->subop<<8))) {
				if (t->op==CBR || t->op==JBR)
				  fprintf(outfile,"\tj%s", op->opstring+1);
				else fprintf(outfile,"\t%s", op->opstring);
				if (byte==BYTE) fprintf(outfile,"b");
				if (byte==WORD) fprintf(outfile,"w");
				if (byte==LONG) fprintf(outfile,"l");
				break;
			}
		if (t->op==JSW) {
			fprintf(outfile,"\t.L%d%s\n",t->labno,t->code);
			cfree(t->code);
		} else if (t->code) {
			fprintf(outfile,"\t%s\n", t->code);
			cfree(t->code);
		} else if (t->op==JBR || t->op==CBR)
			fprintf(outfile,"\t.L%d\n", t->labno);
		else
			fprintf(outfile,"\n");
		break;

	case 0:
		if (t->code) {
			fprintf(outfile,"%s", t->code);
			cfree(t->code);
		}
		fprintf(outfile,"\n");
		break;
	}
	temp = t->forw;
	t->ref = freenodes;
	freenodes = t;
	t = temp;
	}
}

char *copy(p)
register char *p;
{	register char *onp;
	register int n = strlen(p);

	if (n==0) return(0);
	onp = calloc(n+1,1);	
	strcpy(onp,p);
	return(onp);
}

opsetup()
{
	register struct optab *optp, **ophp;
	register char *p;

	for (optp = optab; p = optp->opstring; optp++) {
		ophp = &ophash[(((p[0]<<3)+(p[1]<<1)+p[2])&077777) % OPHS];
		while (*ophp++)
			if (ophp > &ophash[OPHS])
				ophp = ophash;
		*--ophp = optp;
	}
}

oplook()
{
	register struct optab *optp;
	register char *lp, *op;
	static char tmpop[32];
	struct optab **ophp;

	op = tmpop;
	*op = *(op+1) = *(op+2) = 0;
	lp = line;
	while (*lp=='\t' || *lp==' ') lp++;
	while (*lp && *lp!=' ' && *lp!='\t') *op++ = *lp++;
	*op++ = 0;
	while (*lp=='\t' || *lp==' ') lp++;
	curlp = lp;
	ophp = &ophash[(((tmpop[0]<<3)+(tmpop[1]<<1)+tmpop[2])&077777) % OPHS];
	while (optp = *ophp) {
		op = optp->opstring;
		lp = tmpop;
		while (*lp == *op++)
			if (*lp++ == 0)
				return(optp->opcode);
		op--;
		if (*lp=='b' && *(lp+1)==0 && *op==0)
			return(optp->opcode + (BYTE<<8));
		if (*lp=='w' && *(lp+1)==0 && *op==0)
			return(optp->opcode + (WORD<<8));
		if (*lp=='l' && *(lp+1)==0 && *op==0)
			return(optp->opcode + (LONG<<8));
		ophp++;
		if (ophp >= &ophash[OPHS])
			ophp = ophash;
	}
	curlp = line;
	return(0);
}

refcount()
{
	register struct node *p, *lp, *temp;
	static struct node *labhash[LABHS];
	register struct node **hp;

	for (hp = labhash; hp < &labhash[LABHS];)
		*hp++ = 0;
	for (p = first.forw; p!=0; p = p->forw)
		if (p->op==LABEL) {
			labhash[p->labno % LABHS] = p;
			p->refc = 0;
		}
	for (p = first.forw; p!=0; p = p->forw) {
		if (p->op==JBR || p->op==CBR || p->op==JSW) {
			p->ref = 0;
			lp = labhash[p->labno % LABHS];
			if (lp==0 || p->labno!=lp->labno)
			for (lp = first.forw; lp!=0; lp = lp->forw) {
				if (lp->op==LABEL && p->labno==lp->labno)
					break;
			}
			if (lp) {
				temp = nonlab(lp)->back;
				if (temp!=lp) {
					p->labno = temp->labno;
					lp = temp;
				}
				p->ref = lp;
				lp->refc++;
			}
		}
	}
	for (p = first.forw; p!=0; p = lp) {
	  lp = p->forw;
	  if (p->op==LABEL && p->refc==0 && lp && lp->op!=0 && lp->op!=JSW) decref(p);
	}
}

iterate()
{
	register struct node *p, *rp, *p1;

	nchange = 0;
	for (p = first.forw; p!=0; p = p->forw) {
		if ((p->op==JBR||p->op==CBR||p->op==JSW) && p->ref) {
			rp = nonlab(p->ref);
			if (rp->op==JBR && rp->labno && p->labno!=rp->labno) {
				nbrbr++;
				p->labno = rp->labno;
				decref(p->ref);
				rp->ref->refc++;
				p->ref = rp->ref;
				nchange++;
			}
		}
		if (p->op==CBR && (p1 = p->forw)->op==JBR) {
			rp = p->ref;
			do
				rp = rp->back;
			while (rp->op==LABEL);
			if (rp==p1) {
				decref(p->ref);
				p->ref = p1->ref;
				p->labno = p1->labno;
				p1->forw->back = p;
				p->forw = p1->forw;
				p->subop = revbr[p->subop];
				p1->ref = freenodes;
				freenodes = p1;
				nchange++;
				nskip++;
			}
		}
		if (p->op==JBR || p->op==JMP) {
			while (p->forw && p->forw->op!=LABEL && p->forw->op!=DLABEL
				&& p->forw->op!=EROU && p->forw->op!=END
				&& p->forw->op!=0 && p->forw->op!=DATA
				&& p->forw->op!=BSS) {
				nchange++;
				iaftbr++;
				if (p->forw->ref)
					decref(p->forw->ref);
				p1 = p->forw;
				p->forw = p->forw->forw;
				p->forw->back = p;
				p1->ref = freenodes;
				freenodes = p1;
			}
			rp = p->forw;
			while (rp && rp->op==LABEL) {
				if (p->ref == rp) {
					p->back->forw = p->forw;
					p->forw->back = p->back;
					p->ref = freenodes;
					freenodes = p;
					p = p->back;
					decref(rp);
					nchange++;
					njp1++;
					break;
				}
				rp = rp->forw;
			}
			xjump(p);
			p = codemove(p);
		}
	}
}

xjump(ap)
 struct node *ap;
{
	register struct node *p1, *p2, *p3;
	int nxj;

	nxj = 0;
	p1 = ap;
	if ((p2 = p1->ref)==0)
		return(0);
	for (;;) {
		while ((p1 = p1->back) && p1->op==LABEL);
		while ((p2 = p2->back) && p2->op==LABEL);
		if (!equop(p1, p2) || p1==p2)
			return(nxj);
		p3 = insertl(p2);
		p1->op = JBR;
		p1->subop = 0;
		p1->ref = p3;
		p1->labno = p3->labno;
		p1->code = 0;
		nxj++;
		nxjump++;
		nchange++;
	}
}

struct node *insertl(ap)
struct node *ap;
{
	register struct node *lp, *op;

	op = ap;
	if (op->op == LABEL) {
		op->refc++;
		return(op);
	}
	if (op->back->op == LABEL) {
		op = op->back;
		op->refc++;
		return(op);
	}
	lp = getnode();
	lp->op = LABEL;
	lp->labno = isn++;
	lp->ref = 0;
	lp->code = 0;
	lp->refc = 1;
	lp->back = op->back;
	lp->forw = op;
	op->back->forw = lp;
	op->back = lp;
	return(lp);
}

struct node *codemove(ap)
struct node *ap;
{
	register struct node *p1, *p2, *p3;
	struct node *t, *tl;
	int n;

	p1 = ap;
	if (p1->op!=JBR || (p2 = p1->ref)==0)
		return(p1);
	while (p2->op == LABEL)
		if ((p2 = p2->back) == 0)
			return(p1);
	if (p2->op!=JBR && p2->op!=JMP)
		goto ivloop;
	p2 = p2->forw;
	p3 = p1->ref;
	while (p3) {
		if (p3->op==JBR || p3->op==JMP) {
			if (p1==p3)
				return(p1);
			ncmot++;
			nchange++;
			p1->back->forw = p2;
			p1->forw->back = p3;
			p2->back->forw = p3->forw;
			p3->forw->back = p2->back;
			p2->back = p1->back;
			p3->forw = p1->forw;
			decref(p1->ref);
			return(p2);
		} else
			p3 = p3->forw;
	}
	return(p1);
ivloop:
	if (p1->forw->op!=LABEL)
		return(p1);
	p3 = p2 = p2->forw;
	n = 16;
	do {
		if ((p3 = p3->forw) == 0 || p3==p1 || --n==0)
			return(p1);
	} while (p3->op!=CBR || p3->labno!=p1->forw->labno);
	do 
		if ((p1 = p1->back) == 0)
			return(ap);
	while (p1!=p3);
	p1 = ap;
	tl = insertl(p1);
	p3->subop = revbr[p3->subop];
	decref(p3->ref);
	p2->back->forw = p1;
	p3->forw->back = p1;
	p1->back->forw = p2;
	p1->forw->back = p3;
	t = p1->back;
	p1->back = p2->back;
	p2->back = t;
	t = p1->forw;
	p1->forw = p3->forw;
	p3->forw = t;
	p2 = insertl(p1->forw);
	p3->labno = p2->labno;
	p3->ref = p2;
	decref(tl);
	if (tl->refc<=0)
		nrlab--;
	loopiv++;
	nchange++;
	return(p3);
}

comjump()
{
	register struct node *p1, *p2, *p3;

	for (p1 = first.forw; p1!=0; p1 = p1->forw)
		if (p1->op==JBR && (p2 = p1->ref) && p2->refc > 1)
			for (p3 = p1->forw; p3!=0; p3 = p3->forw)
				if (p3->op==JBR && p3->ref == p2)
					backjmp(p1, p3);
}

backjmp(ap1, ap2)
struct node *ap1, *ap2;
{
	register struct node *p1, *p2, *p3, *ptemp;

	p1 = ap1;
	p2 = ap2;
	for(;;) {
		while ((p1 = p1->back) && p1->op==LABEL);
		p2 = p2->back;
		if (equop(p1, p2)) {
			p3 = insertl(p1);
			p2->back->forw = p2->forw;
			p2->forw->back = p2->back;
			ptemp = p2;
			p2 = p2->forw;
			ptemp->ref = freenodes;
			freenodes = ptemp;
			decref(p2->ref);
			p2->labno = p3->labno;
			p2->ref = p3;
			nchange++;
			ncomj++;
		} else
			return;
	}
}

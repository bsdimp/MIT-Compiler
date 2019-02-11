#include "mical.h"
extern char File_name[];

/* process lines from source file, returns when EOF detected */

#define LSIZE	200	/* max size of input line */

/* small info table for each input character */
short cinfo[128] = {
	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,
	ERR,	SPC,	EOL,	SPC,	SPC,	SPC,	ERR,	ERR,
	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,
	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,
	SPC,	ERR,	QUO,	IMD,	S+T,	ERR,	ERR,	CHR,
	LP,	RP,	MUL,	ADD,	COM,	SUB,	S+T,	ERR,
	D+T,	D+T,	D+T,	D+T,	D+T,	D+T,	D+T,	D+T,
	D+T,	D+T,	COL,	EOS,	ERR,	EQL,	ERR,	ERR,
	IND,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
	S+T,	S+T,	S+T,	LB,	ERR,	RB,	ERR,	S+T,
	ERR,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
	S+T,	S+T,	S+T,	ERR,	EOL,	ERR,	NOT,	S+T
};

char *sassign(),*sdefer(),*exp(),*term();
int slabel();
char iline[LSIZE];	/* current input line resides */
int Line_no;		/* current input line number */
char Code[CODE_MAX];	/* where generated code is stored */
long Dot;		/* offset in current csect */
int BC;			/* size of code for current line */

extern lflag;

main(argc,argv)
  char *argv[];
  {	Init(argc,argv);
	scan();
	End();
	scan();
	End();
	exit(Errors? -1: 0);
}

scan()
  {	register int i;
	register char *p;	/* pointer into input line */
	char *token;		/* pointer to beginning of last token */
	struct opcode *opcode;		/* of optable entry of current line */

	while (fgets(iline,LSIZE,stdin) == iline) {
	  Line_no++;

	/* make listing if desired */
	  if (Pass > 1 && lflag)
		printf("%d\t%s", Line_no, iline);

	/* handle info passed on by cpp */
	  if (iline[0] == '#') {
		sscanf(iline,"# %d \"%[^\"]",&Line_no,File_name);
		continue;
	  }

	  p = iline;
	  BC = 0;

	  /* see what's the first thing on the line. if newline or comment
	   * char just ignore line all together.  if start of symbol see
	   * what follows.  otherwise error.
	   */
 restart: skipb(p);
	  i = cinfo[*p];	/* see what we know about next char */
	  if (i == EOS) { p++; goto restart; }
	  else if (i == EOL) continue;
	  else if (!(i & (S|D))) { Prog_Error(E_BADCHAR); continue; }

	  /* what follows is either label or opcode, gobble it up */
	  token = p;
	  skips(p);
	  skipb(p);
	  i = cinfo[*p];

	  /* if next char is ":", this is label definition */
	  if (i == COL) { p++; slabel(token); goto restart; }

	  /* if next char is "=", this is label assignment */
	  if (i == EQL) {
	    p = sassign(++p,token);
	    if ((i = cinfo[*p])!=EOL && i!=EOS) Prog_Error(E_BADCHAR);
	    goto restart;
	  }

	  /* otherwise this must be opcode, find its index */
	  if ((opcode = sopcode(token)) == (struct opcode *)NULL) {
	    Prog_Error(E_OPCODE);
	    continue;
	  }

	  if (i==EOL || i==EOS) { numops = 0; goto doins; }

	  /* keep reading operands until we run out of room or hit EOL */
	  for (numops = 1; numops <= OPERANDS_MAX; numops++) {
	    p = soperand(p,&operands[numops-1]);
	    /* printop(&operands[numops-1]); */
	    skipb(p);
	    i = cinfo[*p];
	    if (i == COM) { p++; continue; }
	    if (i==EOL || i==EOS) goto doins;
	    Prog_Error(E_OPERAND);
	    goto next;
	  }
	  Prog_Error(E_NUMOPS);
  next:	  continue;

  doins:  BC = 0;
	  Instruction(opcode);
	  if((Pass > 1) && lflag) printcode();
	  Dot += BC;
	  Cur_csect->dot_cs = Dot_bkt->value_s = Dot;
	  if (Dot > Cur_csect->len_cs) Cur_csect->len_cs = Dot;
	}
}

/* lookup token in opcode hash table, return NULL if not found */
struct opcode *
sopcode(token)
  register char *token;
  {	register char *p;
	register struct ins_bkt *ibp;
	char mnem[50];

	/* make asciz version of mnemonic */
	p = mnem;
	while (cinfo[*token] & T) *p++ = *token++;
	*p = 0;

	/* look through appropriate hash bucket */
	ibp = ins_hash_tab[Hash(mnem)];
	while (ibp) {
	  if (strcmp(ibp->text_i,mnem) == 0) return(ibp->code_i);
	  ibp = ibp->next_i;
	}

	return(NULL);
}

/* handle definition of label */
slabel(token)
  register char *token;
  {	register char *p;
	register struct sym_bkt *sbp;
	char lab[50];

	/* make asciz version of label */
	p = lab;
	while (cinfo[*token] & T) *p++ = *token++;
	*p = 0;

	/* find/enter symbol in the symbol table */
	sbp = Lookup(lab);

	/* on pass 1 look for multiply defined symbols.  if ok, label
	 * value is dot in current csect
	 */
	if (Pass==1) {
	  if (sbp->attr_s & (S_LABEL|S_REG)) Prog_Error(E_MULTSYM);
	  sbp->csect_s = Cur_csect;
	  sbp->value_s = Dot;
	} else if (sbp->csect_s!=Cur_csect || sbp->value_s!=Dot)
	  Prog_Error(E_MULTSYM);
	sbp->attr_s |= S_LABEL | S_DEC | S_DEF;

	if (!(cinfo[lab[0]] & D)) Last_symbol = sbp;
}

/* handle assignment to a label, return updated line pointer */
char *sassign(lptr,token)
  register char *token;
  register char *lptr;
  {	register char *p;
	register struct sym_bkt *sbp;
	struct oper value;
	char lab[50];

	/* make asciz version of label */
	p = lab;
	while (cinfo[*token] & T) *p++ = *token++;
	*p = 0;

	/* find/enter symbol in the symbol table, and get its new value */
	sbp = Lookup(lab);
	lptr = exp(lptr,&value);

	/* if assignment is to dot, we'll treat it specially */
	if (sbp == Dot_bkt) {
	  if (value.sym_o && value.sym_o->csect_s!=Cur_csect)
	    Prog_Error(E_OPERAND);
	  if ( Dot > value.value_o)
		Prog_Error(E_OPERAND);
	  else
		Pad_Text(value.value_o - Dot);
	  Dot = value.value_o;
	  Cur_csect->dot_cs = Dot_bkt->value_s = Dot;
	  if (Dot > Cur_csect->len_cs) Cur_csect->len_cs = Dot;
	} else {
	  sbp->value_s = value.value_o;
	  sbp->csect_s = (value.sym_o!=NULL) ? value.sym_o->csect_s : NULL;
	  if (sbp->attr_s & S_LABEL) Prog_Error(E_EQUALS);
	  else sbp->attr_s = (value.sym_o!=NULL) ?
	    (value.sym_o->attr_s & ~(S_LABEL|S_PERM)):
	    (S_DEC | S_DEF|S_DEF1);
	}

	/* return update line pointer */
	skipb(lptr);
	return(lptr);
}

/* Hashing routine for Symbol and Instruction hash tables */
Hash(s)
  register char *s;
  {	register int i = 0;

	while (*s) i = i*10 + *s++ - ' ';
	i = i % HASH_MAX;
	return(i<0 ? i+HASH_MAX : i);
}

/* Fetches operand value and register subfields and loads them into
 * the operand structure. This routine will fetch only one set of value
 * and register subfields. It will move line pointer to first untouched char.
 */
char *soperand(lptr,opnd)
  register char *lptr;
  struct oper *opnd;
  {	char c;

	opnd->type_o = opnd->flags_o = opnd->reg_o = 0;
	opnd->value_o = opnd->disp_o = 0;
	opnd->sym_o = NULL;

	skipb(lptr);
	if (cinfo[*lptr] == IMD) {
	  lptr = exp(++lptr,opnd);
	  if (opnd->type_o == t_reg) Prog_Error(E_REG);
	  opnd->type_o = t_immed;
	} else {
	  lptr = exp(lptr,opnd);
	  skipb(lptr);
	  while (1) switch (cinfo[*lptr]) {
	    default:	return(lptr);

	    case COL:	switch (*++lptr) {
			  case 'W':
			  case 'w': opnd->type_o = t_abss;
				    lptr++;
				    continue;
			  case 'L':
			  case 'l': opnd->type_o = t_absl;
				    lptr++;
				    continue;
			  default:  return(lptr);
			}

	    case IND:	if (opnd->type_o != t_reg) return(lptr);
			opnd->type_o = t_defer;
			lptr++;
			continue;

	    case LP:	if(opnd->type_o != t_memind)
				opnd->type_o = t_defer;
			lptr = sdefer(lptr,opnd);
			continue;

	    case RP:	if(opnd->type_o != t_memind) return(lptr);
			lptr++;
			continue;

	    case LB:	if(opnd->type_o == t_immed)
				Prog_Error(E_OPERAND);
			lptr = sdefer(lptr,opnd);
			continue;

	    case RB:	lptr++;
			continue;

	  }
	}
	return(lptr);
}

/* Process Displacement or Index Deferred Suboperands */
char *sdefer(lptr,opnd)
  register struct oper *opnd;
  register char *lptr;
  {	
	long tvalue;
	char ttype;

	if ((opnd->type_o != t_defer) && (opnd->type_o != t_memind) && 
			(cinfo[*lptr] != LB)) {
	  Prog_Error(E_OPERAND); return(lptr);
	}
	tvalue = opnd->value_o;
	ttype = opnd->type_o;
	lptr = exp(++lptr,opnd);

	skipb(lptr);
	switch (cinfo[*lptr]) {
	  case RP:	if(opnd->type_o != t_reg){
				Prog_Error(E_OPERAND);
				return(lptr++);
			}
			if(ttype == t_defer)
				opnd->type_o = t_displ;
			else opnd->type_o = ttype;

			opnd->reg_o = opnd->value_o;
			opnd->value_o = tvalue;
			lptr++;
			break;

	  case LP:	if(opnd->type_o != t_normal){
				if(opnd->type_o == 0) tvalue = 0;
				else{
					Prog_Error(E_OPERAND);
					return(lptr);
				}
			}
			opnd->type_o = t_memind;
			opnd->disp_o = tvalue;
			break;

	  case COL:	if (opnd->type_o!=t_reg ) {
			  Prog_Error(E_OPERAND); return(lptr);
			}
			opnd->ireg_o = opnd->value_o;
			opnd->value_o = tvalue;
			opnd->type_o = ttype;
			lptr++;
			switch (*lptr++) {
			  case 'B':
			  case 'b':	opnd->flags_o |= O_BINDEX;
					break;
			  case 'Q':
			  case 'q':	opnd->flags_o |= O_QINDEX;
					break;
			  case 'W':
			  case 'w':	opnd->flags_o |= O_WINDEX;
					break;
			  case 'L':
			  case 'l':	opnd->flags_o |= O_LINDEX;
					break;
			  default:	Prog_Error(E_OPERAND);
					return(lptr);
			}
			skipb(lptr);
			if (cinfo[*lptr] != RB) {
			  Prog_Error(E_OPERAND); return(lptr);
			}
			break;

	default:	return(lptr);
	}						
	return(lptr);
}

/* read expression */
char *exp(lptr,Arg1)
  register char *lptr;
  register struct oper *Arg1;
  {	struct oper Arg2;	/* holds value of right hand term */
	register int i;
	register char Op;	/* operator character */

/*	Arg2.type_o = Arg2.flags_o = Arg2.reg_o = 0;
	Arg2.value_o = Arg.disp_o = 0;
*/
	skipb(lptr);				/* Find the operator */
	i = cinfo[*lptr];
	if (i==LP || i==EOL || i==COM)
	 {		/* nil operand is zero */
	  Arg1->sym_o = NULL;
	  Arg1->value_o = 0;
	  return(lptr);
	 }
	lptr = term(lptr,Arg1);

	while (1) {
	  skipb(lptr);
	  switch (cinfo[*lptr]) {
	    case ADD:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o && Arg2.sym_o) break;
			if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;
			Arg1->value_o += Arg2.value_o;
			Arg1->flags_o |= Arg2.flags_o&O_COMPLEX;
			continue;

	    case MUL:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			Arg1->value_o *= Arg2.value_o;
			Arg1->flags_o |= Arg2.flags_o&O_COMPLEX;
			continue;

	    case SUB:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg2.sym_o)		/* if B is relocatable, */
			  if (Arg1->sym_o) {	/* and A is relocatable, */
			    if (Arg2.sym_o->csect_s != Arg1->sym_o->csect_s) break; /* break into error */
			    else {
			      Arg1->sym_o = NULL;	/* result is absolute (no offset) */
			      Arg1->flags_o |= O_COMPLEX;	/* but not a simple address for sdi's */
			    }
			  } else break;		/* if B rel., and A is not, then break into relocation error */
			Arg1->value_o -= Arg2.value_o;
			continue;

	    default:	return(lptr);
	  }
	Prog_Error(E_RELOCATE);
	return(lptr);
	}
}

/* read term: either symbol, constant, or unary minus */
char *term(lptr,Vp)
  register char *lptr;
  register struct oper *Vp;
  {	register int i;
	register struct sym_bkt *sbp;
	register char *p;
	register int base = 10;
	register long val;
	char token[50];

	skipb(lptr);
	i = cinfo[*lptr];

	/* here for number */
	if (i & D) {
	  p = lptr;
	  if (*lptr == '0') {
	    lptr++;
	    if (*lptr=='x' || *lptr=='X') { lptr++; base = 16; }
	    else base = 8;
	  }
	  val = 0;
	  if (base == 16) while (1) {
	    if (cinfo[*lptr] & D) val = val*16 + *lptr++ - '0';
	    else if (*lptr>='A' && *lptr<='F')
	      val = val*16 + *lptr++ - 'A' + 10;
	    else if (*lptr>='a' && *lptr<='f')
	      val = val*16 + *lptr++ - 'a' + 10;
	    else break;
	  } else while (cinfo[*lptr] & D) val = val*base + *lptr++ - '0';

	  if (*lptr == '$') { lptr = p; goto sym; }

	  Vp->value_o = val;
	  Vp->sym_o = NULL;
	  Vp->type_o = t_normal;
	  return(lptr);
	}

	/* here for symbol name */
	if (i & S) {
    sym:  p = token;
	  while (cinfo[*lptr] & T) *p++ = *lptr++;
	  *p = 0;	  
	  sbp = Lookup(token);		/* find its symbol bucket */

	  if (sbp->attr_s & S_DEF)	/* if it's defined, use its value */
	    Vp->value_o = sbp->value_s;
	  else Vp->value_o = 0;

	  if (sbp->attr_s & S_REG) Vp->type_o = t_reg;
	  else {
	    Vp->sym_o = (sbp->attr_s & S_DEF) &&
			 (sbp->csect_s == 0 || (sbp->csect_s->attr_cs & R_ABS))
				    ? 0 : sbp;
	    Vp->type_o = t_normal;
	  }
	  return(lptr);
	}

	/* check for unary minus */
	if (i == SUB) {
	  lptr = term(++lptr,Vp);
	  if (Vp->sym_o) Prog_Error(E_RELOCATE);
	  Vp->value_o = -(Vp->value_o);	/* and finally do it */
	  return(lptr);
	}

	/* check for complement */
	if (i == NOT) {
	  lptr = term(++lptr,Vp);
	  if (Vp->sym_o) Prog_Error(E_RELOCATE);
	  Vp->value_o = ~(Vp->value_o);	/* and finally do it */
	  return(lptr);
	}

	/* here for string */
	if (i == QUO) {
	  Vp->value_o = (long)(lptr+1);
	  do i = cinfo[*++lptr]; while (i!=EOL && i!=QUO);
	  *lptr++ = 0;
	  Vp->sym_o = NULL;
	  Vp->type_o = t_string;
	  return(lptr);
	}

	Prog_Error(E_TERM);
	return(lptr);
}

char *tnames[] = {
  "?", "reg", "defer", "postinc", "predec", "displ",
  "index", "abss", "absl", "immed", "normal", "string"
};

printop(o)
register struct oper *o;
{
	fprintf(stderr,"operand %d: type=(%x,%s) ",
		numops, o->type_o, tnames[o->type_o]);
	if (o->sym_o)
		fprintf(stderr,"csect=%s sym=%s ",
			o->sym_o->csect_s->name_cs, o->sym_o->name_s);
	fprintf(stderr,"value=%ld reg=%d displ=%ld\n",
		o->value_o, o->reg_o, o->disp_o);
}


printcode() {
	register char *cp;

	printf("\t%lx:\t",Dot);
	for(cp = Code; cp < CCode ; cp++) {
		if((*cp >= 0) && (*cp < 0x10))
			printf("0%1x ",*cp & 0xFF);
		else
			printf("%2x ",*cp & 0xFF);
	}
	printf("\n");
}
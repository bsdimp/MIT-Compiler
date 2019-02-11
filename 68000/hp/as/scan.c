#include "mical.h"

/* process lines from source file, returns when EOF detected */

#define REGSIZE	32	/* # bints in a register */
/* definitions for operand table */

#define ZER 	0
#define	ONE	1
#define TWO	2
#define MOR 	3
#define PSU    99


/* This table give the number of operands an opcode can use */

unsigned short opnum[HASH_MAX]={   0,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,
				 ONE,ONE,TWO,TWO,ONE,ONE,ONE,ONE,ONE,ONE,
				 ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,
				 ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,TWO,ONE,
				 ONE,TWO,ONE,ONE,ONE,ONE,TWO,ONE,ONE,ONE,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,ONE,
				 ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE, 
				 
				 ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,TWO, 
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,ONE,ONE,ONE,
				 ONE,ONE,ONE,ONE,ZER,ONE,ONE,ONE,TWO,TWO,
				 TWO,TWO,TWO,TWO,ONE,ZER,TWO,TWO,TWO,TWO,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,ZER,ZER,
				 ZER,TWO,ONE,ONE,ONE,ONE,ONE,ONE,ONE,ONE,
				 ONE,ONE,ONE,ONE,ONE,ONE,ONE,TWO,TWO,TWO,
				 TWO,TWO,TWO,TWO,TWO,TWO,ONE,ONE,ONE,ONE,
				 ONE,ZER,ONE,ONE,ONE,ONE,PSU,PSU,PSU,PSU,
				 
				 ZER,ZER,PSU,TWO,ZER,ONE,ONE,TWO,0,0,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,0,0,
				 TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,TWO,
				 0,0,TWO,TWO,TWO,0,0,0,TWO,TWO,
				 TWO,TWO,TWO,0,0,ONE,MOR,MOR,MOR,ONE,
				 ONE,ZER,0,0,0,0};
	     


/* small info table for each input character */
short cinfo[128] = {
/*  0*/	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,
/*  8*/	ERR,	SPC,	EOL,	SPC,	SPC,	SPC,	ERR,	ERR,
/* 16*/	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,
/* 24*/	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,	ERR,
/* 32*/	SPC,	BOR,	QUO,	IMM,	D+T,	ERR,	ERR,	ERR,
/* 40*/	LP,	RP,	S+T,	ADD,	COM,	SUB,	S+T,	DIV,
/* 48*/	D+T,	D+T,	D+T,	D+T,	D+T,	D+T,	D+T,	D+T,
/* 56*/	D+T,	D+T,	COL,	EOL,	SHL,	EQL,	SHR,	S+T,
/* 64*/	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
/* 72*/	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
/* 80*/	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
/* 88*/	S+T,	S+T,	S+T,	ERR,	ERR,	BXO,	ERR,	S+T,
/* 96*/	ERR,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
/*104*/	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
/*112*/	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,	S+T,
/*120*/	S+T,	S+T,	S+T,	ERR,	EOL,	ERR,	NOT,	S+T  
};

char *sassign(),*sdefer(),*exp(),*term(),*Mask();
int slabel();

extern int transport; /* defined in init.c -- ANNY */
extern short aflag;	/* defined in init.c */
extern FILE *A_file;	/* file for optional listing */
char iline[LSIZE];	/* current input line resides */
int Line_no;		/* current input line number */
char Code[CODE_MAX];	/* where generated code is stored */
long Dot;		/* offset in current csect */
int BC;			/* size of code for current line */
int displaced;
FILE *infile, *inclarray[20];
int inclptr;

main(argc,argv)
  char *argv[];
  {	Init(argc,argv);
#ifdef debug
fprintf(stderr,"		Pass 1\n");
#endif
	scan();
	End();
#ifdef debug 
fprintf(stderr,"\n		Pass 2\n");
#endif
	scan();
	End();
	exit(Errors? -1: 0);
}

scan()
  {	register short i;	/* MFM */
	register char *p;	/* pointer into input line */
	char *token;		/* pointer to beginning of last token */
	int opindex;		/* index of opcode on current line */

do
{	while (fgets(iline,LSIZE,infile) == iline) {

	  Line_no++;

#	  ifdef RANDEL
	  printf("\nLINE %d\n",Line_no);
#	  endif 

	  p = iline;
	  BC = 0;
	  Code_length = 0;

	  /* see what's the first thing on the line. if newline or comment
	   * char just ignore line all together.  if start of symbol see
	   * what follows.  otherwise error.
	   */
 restart: skipb(p);
	  i = cinfo[*p];	/* see what we know about next char */
	  if (i == EOL || *p == '*')
		goto next;
	  if (!(i & (S|D))) { 

#	    ifdef debug
	    printf("3--bad char is %c\n",*p);
#	    endif

	    Prog_Error(E_BADCHAR); 
	    goto next; }

	  /* what follows is either label or opcode, gobble it up */
	  token = p;

#	  ifdef debug
	  printf("Token is %c\n",*token);
#	  endif

	  skips(p);
	  skipb(p);
	  i = cinfo[*p];

	  /* if next char is ":", this is label definition */
	  if (i == COL) { 
		p++; 
		slabel(token); 
		goto restart; 
		}

	  /* if next char is "=", this is label assignment */
	  if (i == EQL /*|| ((*p=='e')&&(*(p+1)=='q')&&(*(p+2)=='u')) 	*/) {           /* this part commented out until further discussion on subject -- acs */

#	    ifdef debug
	    printf("p is %c\n",*p);
#	    endif

	/*  if (*p=='e') 
		p+=3;
	    else	*/  /* commented out until later - see above -- acs */
		p++;
	    skipb(p);
	    p = sassign(p,token);
	    if (!((cinfo[*p] == EOL) || (cinfo[*p] == SPC))) {

#	      ifdef debug
	      printf("1--bad char is %c\n",*p);
	      printf("cinfo[*p] = %d\n",cinfo[*p]);
	      printf("integer of p = %d\n",*p);
#	      endif

	      Prog_Error(E_BADCHAR); 
	    }
	    goto next;
	  }

	  /* otherwise this must be opcode, find its index */

#	  ifdef debug
	  printf("opindex=%d, sopcode(token)=%d, token=%d\n",opindex,sopcode(token),token);
#	  endif
	  opindex = sopcode(token);
	  if ((opindex == 300) && (transport)) 
	  /* allows for pascal psuedo ops (in lc) if transport set */
	    {
	    opindex = 0;
	    goto restart;
	    }

	  if (opindex == 0) {

#	    ifdef debug
	    printf("opindex=%d\t",opindex);
	    printf("sopcode(token)=%d\t",sopcode(token));
	    printf("token=%d\n",token);
#	    endif

	    Prog_Error(E_OPCODE);
	    goto next;
	  }

#	  ifdef debug
	  printf("OPNUM[OPINDEX] = %d\n",opnum[opindex]);
#	  endif

	  if ((i == EOL) || (opnum[opindex] == ZER)) { numops = 0; goto doins; }

	  /* keep reading operands until we run out of room or hit EOL */
	  skipb(p);
	  for (numops = 1; numops <= opnum[opindex]; numops++) {
	    p = soperand(p,&operands[numops-1]);


#	    ifdef randel
	    fprintf(stderr,"FINAL TYPE IS %d\n",operands[numops-1].type_o);
#	    endif

	    skipb(p);

#	    ifdef randel
	    fprintf(stderr,"just returned from soperand with *p = %c\n",*p);
#	    endif

	    i = cinfo[*p];
	    if (i == COM) { p++; continue; }
	    if ((i == EOL) && (numops != opnum[opindex])){

#	      ifdef debug 
	      printf("cinfo is EOL\nnumops=%d\nopnum[opindex]=%d\n",numops,opnum[opindex]);
#	      endif

	      goto e_numops;  }   

	    else{

#	      ifdef randel
	      printf("CINFO says %d\n",i);
	      printf("CHAR is %c\n",*p);
#	      endif

	      goto doins;}

	  /*Prog_Error(E_OPERAND); never reached */

	  }
e_numops: if (opnum[opindex]!=99)      /*if it's not a psuedop*/
	  { Prog_Error(E_NUMOPS);
	    goto next; }

  doins:  Instruction(opindex);
          Dot += BC;

#	  ifdef DEBUG
	  fprintf(stderr,"		Dot and BC being updated by %d\n", BC);
#	  endif

	  Cur_csect->dot_cs = Dot_bkt->value_s = Dot;
	  if (Dot > Cur_csect->len_cs) Cur_csect->len_cs = Dot;
next:	if (aflag && (Pass == 2)) listsrc();	}
	if (inclptr >= 0)
	{	if (inclptr > 0) fclose(infile);
		infile = inclarray[inclptr];
	}
}
while (inclptr-- >= 0);
inclptr = -1;
}

/* lookup token in opcode hash table, return 0 if not found */
int sopcode(token)
  register char *token;
  {	register char *p;
	register struct ins_bkt *ibp;
	char mnem[SYMLENGTH];

	/* make asciz version of mnemonic */
	p = mnem;
	while (cinfo[*token] & T){

#	  ifdef debug
	  printf("%c",*token);
#	  endif

	  *p++ = *token++;
	}
	*p = 0;

#	ifdef debug 
	printf("\n");
#	endif 

	/* look through appropriate hash bucket */
	ibp = ins_hash_tab[Hash(mnem)];
	while (ibp) {
	  if (strcmp(ibp->text_i,mnem) == 0) return(ibp->code_i);
	  ibp = ibp->next_i;
	}

	return(0);
}

/* handle definition of label */
slabel(token)
  register char *token;
  {	register char *p;
	register struct sym_bkt *sbp;
	char lab[SYMLENGTH];

	/* make asciz version of label */
	p = lab;
	while (cinfo[*token] & T) *p++ = *token++;
	*p = 0;

	/* find/enter symbol in the symbol table */
	sbp = Lookup(lab);

	/* on pass 1 look for multiply defined and undefinable symbols.  
	 * if ok, label value is dot in current csect
	 */

	if (Pass==1) {
	  if (sbp->attr_s & (S_LABEL | S_REG)) sbp->attr_s |= S_CANTDEFINE;
	  sbp->attr_s |= S_LABEL | S_DEC | S_DEF;
	  sbp->csect_s = Cur_csect;
	  sbp->value_s = Dot;

#	  ifdef DEBUG
	  fprintf(stderr,"	Pass 1		");
	  fprintf(stderr,"slabel(%s) = %d\n",lab,Dot);
	  fprintf(stderr,"sbp->value_s = %d\n", sbp-> value_s);
	  fprintf(stderr,"	Cur_csect = %x\n",Cur_csect);
	  fprintf(stderr,"	sbp->csect_s = %x\n", sbp-> csect_s);
	  fprintf(stderr,"		sbp->attr_s = %x\n", sbp-> attr_s);
#	  endif

	}   /* otherwise it's pass 2 */
	else 
        {	
	  if (sbp->attr_s & S_CANTDEFINE) Prog_Error(E_MULTSYM);

	  if (sbp->csect_s!=Cur_csect || sbp->value_s!=Dot) 
	  {

#	  	ifdef DEBUG
	  	fprintf(stderr,"	Pass 2		");
	  	fprintf(stderr,"slabel(%s) = %d\n",lab,Dot);
	  	fprintf(stderr,"sbp->value_s = %d\n", sbp-> value_s);
	  	fprintf(stderr,"	Cur_csect = %x\n",Cur_csect);
	  	fprintf(stderr,"	sbp->csect_s = %x\n", sbp-> csect_s);
	  	fprintf(stderr,"		sbp->attr_s = %x\n", sbp-> attr_s);
#	  	endif

	  	Prog_Error(E_GLOBL);
	   }
  	}
	if (!(cinfo[lab[0]] & D)) Last_symbol = sbp;

}

/* handle assignment to a label, return updated line pointer */
char *sassign(lptr,token)
  register char *token;  /* points to left side of = */
  register char *lptr;  /* points to right side of = */
  {	register char *p;
	register struct sym_bkt *sbp;
	struct oper value;
	char lab[SYMLENGTH];

	/* make asciz version of label */
	p = lab;
	while (cinfo[*token] & T) *p++ = *token++;
	*p = 0;

	/* find/enter symbol in the symbol table, and get its new value */
	sbp = Lookup(lab);  /* look up left-hand symbol */
	skipb(lptr);   /* skip in case there's blanks */
	lptr = exp(lptr,&value);  /* exp on right-hand symbol */

	/* if assignment is to dot, we'll treat it specially */
	if (sbp == Dot_bkt) {

#	  ifdef debug
	  fprintf(stderr,"Assignment to dot\n");
#	  endif    

	  if (value.sym_o && value.sym_o->csect_s!=Cur_csect)
		Prog_Error(E_OPERAND);
	  Dot = value.value_o;
	  Cur_csect->dot_cs = Dot_bkt->value_s = Dot;
	  if (Dot > Cur_csect->len_cs) Cur_csect->len_cs = Dot;
	} else {
	  sbp->value_s = value.value_o;

#	  ifdef debug
	  fprintf(stderr,"at pt 2 in sassign.sbp->value_s set to value_o = %d\n", sbp->value_s);
        /*fprintf(stderr,"sbp->csect_s = %d\n",sbp->csect_s);
	  fprintf(stderr,"value.sym_o = %d\n",value.sym_o);
	  fprintf(stderr,"value.sym_o->csect_s = %d\n",value.sym_o->csect_s);*/
#	  endif

	  sbp->csect_s = (value.sym_o!=NULL) ? value.sym_o->csect_s : NULL;
	  if (sbp->attr_s & S_LABEL) Prog_Error(E_EQUALS);
	  else sbp->attr_s |= (value.sym_o!=NULL) ?	/* MFM */
	    (value.sym_o->attr_s & ~(S_LABEL|S_PERM)): (S_DEC | S_DEF);
	}

#	ifdef debug
	fprintf(stderr,"sassign(%s) = %ld\n",lab,value.value_o);
	if (value.sym_o)
	  fprintf(stderr,"csect=%s sym=%s ",
		  value.sym_o->csect_s->name_cs,value.sym_o->name_s);
	fprintf(stderr,"value=%ld reg=%d displ=%ld\n",
		value.value_o,value.reg_o,value.disp_o);
#	endif

	/* return update line pointer */
	if ((*lptr != ' ') && (cinfo[*lptr] != EOL) && (cinfo[*lptr] != SPC))
	{

#	  ifdef debug
	  printf("2--bad char is %c\n",*p);
#	  endif

	  Prog_Error(E_BADCHAR);
	}
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



/*                           SOPERAND                                */

/* Fetches operand value and register subfields and loads them into
 * the operand structure. This routine will fetch only one set of value
 * and register subfields. It will move line pointer to first untouched char.
 */
char *soperand(lptr,opnd)

  register char *lptr; 
  register struct oper *opnd;			/* MFM */

{	char c;
	int  parenflag;
	int  predecflag;
 
	parenflag=0;  /* flag to tell us if a left paren has been encountered */
	predecflag=0; /* flag to tell us if a predecremt has been encountered */
	displaced=0;  /* flag to tell us if we are a displaced type operand */

	opnd->type_o = opnd->flags_o = opnd->reg_o = 0;
	opnd->value_o = opnd->disp_o = 0;
	opnd->sym_o = NULL;

#	ifdef anny 
	printf("fetching operand...%c\n",*lptr);
#	endif
	
	if (cinfo[*lptr] == IMM)                  /* immediate mode */
	{
	  if (*(++lptr) == '<')  
		{
		lptr++;
		lptr = Mask(lptr,&opnd->value_o);/*it's a reg list, make mask*/
		opnd->sym_o = NULL;
		}
	  else 
		{
		lptr = exp(lptr,opnd);
	  	if (opnd->type_o == t_reg) Prog_Error(E_REG);
		}
	  opnd->type_o = t_immed;                         
	} 
	else 
	{
	  if (*lptr == '-') 
	  {
		if (*(lptr+1) == '(') 
		{
		  lptr++; 
		  predecflag=1;
		}
	  }
	  if (*lptr == '(') { parenflag=1; lptr++; }

#	  ifdef Annette
	  fprintf(stderr,"going into exp with lptr at %c\n",*lptr);
#	  endif

	  lptr = exp(lptr,opnd);  /* eval next expr */

	  if ((parenflag) && (!predecflag)) lptr=sdefer(lptr,opnd); /* in case it's simple defer */

#	  ifdef annette	
	  printf("sop1--type %d\n",opnd->type_o);
#	  endif

#	  ifdef anny
	  printf("lptr points to %c\n",*lptr);
#	  endif	   

	  while (1) switch (cinfo[*lptr]) {
	    default:	if (cinfo[*(lptr+1)] == LP) {
			  lptr++;
			  continue;
			}
			else
	                  return(lptr);

	    case COM: 	/**/
#			ifdef anny
			printf("got to COMMA in sdefer\n");
#			endif
			return(lptr);					      

	    case S+T:	if (*lptr != '.') return (lptr); /*not period so deflt*/
			switch (*++lptr) {
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

	    case ADD:	opnd->type_o = t_postinc;
			lptr++;
			continue;

	    case RP:    if (!parenflag) Prog_Error(E_OPERAND);
			if (predecflag) opnd->type_o = t_predec;
			lptr++;
			continue;

            case LP:	if (opnd->type_o == t_normal) displaced = 1;
			else displaced = 0;
			lptr = sdefer(++lptr,opnd);                         
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
      register int reg = (int)opnd->value_o;

#ifdef annette  
printf("displaced = %d\n",displaced);
#endif
#ifdef debug 
printf("in sdefer ...\n");
#endif
	if (displaced) 
	{	opnd->disp_o = opnd->value_o;
		opnd->type_o = t_displ;
	}
	lptr = exp(lptr,opnd);   /* find the next exp which has to be reg */
	opnd->reg_o = opnd->value_o;  /* put into subreg for register field */

	if (opnd->sym_o != NULL)
	  if (!(opnd->sym_o->attr_s & S_RELATIVE))
	    if (displaced) opnd->value_o=opnd->disp_o; 
/*have to do this because in prev versions displacement comes last so it's expected to still be in val fld */

/*	lptr = exp(lptr,opnd);  /* get next expression */

	switch (cinfo[*lptr]) {
	  case RP:
#			ifdef annette
			printf("In case RP: type = %d; disp = %d;\n",opnd->type_o,opnd->disp_o);
#			endif

	                if ((opnd->type_o == t_reg) && (!displaced))
			       opnd->type_o = t_defer;  /* simple indirect */ 
			else 
			  opnd->type_o = t_displ; /* indirect w/ displacement */
			/* last line also handles indexed */
#			ifdef annette
			printf("3) type is %d\n",opnd->type_o);
#			endif
			lptr++;
			break;

	  case COM:	/*opnd->disp_o=opnd->value_o;/*put val in disp field*/ 
			lptr = exp(++lptr,opnd);   /* get new expression */
#			ifdef annette  
			printf("4) type is %d\n",opnd->type_o);
			printf("*lptr = %c\n",*lptr);
#			endif
	                /* must be of reg type & next char must be '.' or RP */
	                if ((opnd->type_o!=t_reg) || (!(*lptr=='.') && (cinfo[*lptr]!=RP)))  
			{
#ifdef anny 
printf("In case COM error trap\n");
#endif
			  Prog_Error(E_OPERAND); return(lptr);
			}
			if (cinfo[*lptr]==RP) /*reg indirect w/ indx dflt to W*/ 
			{
			  opnd->flags_o |= O_WINDEX; /* set flg to word deflt */
			  opnd->type_o = t_index; /* assign type */
#ifdef annette
printf("5) type is %d\n",opnd->type_o);
printf("5) register is %d\n",opnd->type_o);
#endif
			  return(++lptr);  /* return */  
			}
			lptr++;
			switch (*lptr++) {
			  case 'W':
			  case 'w':	opnd->flags_o |= O_WINDEX;
					break;
			  case 'L':
			  case 'l':	opnd->flags_o |= O_LINDEX;
					break;
			  default:	Prog_Error(E_OPERAND);
					return(lptr);
			}
			if (cinfo[*lptr] != RP) {
#ifdef anny 
printf("in cinfo!=RP error trap \n");
#endif
			  Prog_Error(E_OPERAND); return(lptr);
			}
			opnd->type_o = t_index;
#ifdef annette  
printf("6) type is %d\n",opnd->type_o);
#endif
			lptr++;
			return(lptr);

	default:	break;
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
	
	i = cinfo[*lptr];
	if (i==EOL || i==COM || i==SPC) {        /* nil operand is zero */
#ifdef debug
fprintf(stderr,"NIL OPERAND\n");
#endif
	  Arg1->sym_o = NULL;
	  Arg1->value_o = 0;
	  return(lptr);
	 }
	lptr = term(lptr,Arg1);

	while (1) {
	  /* skipb(lptr); */
	  switch (cinfo[*lptr]) {
	    case LP:  /*Arg1->type_o = t_displ;
			Arg1->disp_o = Arg1->value_o;*/
#			ifdef anny 
			printf("found LP in exp\n");
#			endif
			return(lptr);
	    case ADD:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o && Arg2.sym_o) break;
			if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;
			Arg1->value_o += Arg2.value_o;
			Arg1->flags_o |= Arg2.flags_o&O_COMPLEX;
			continue;

	    case S+T:	if (*lptr == '*')
			{
			   lptr = term(++lptr,&Arg2);
		     	   if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			   if (Arg1->sym_o || Arg2.sym_o) break;
			   Arg1->value_o *= Arg2.value_o;
			   Arg1->flags_o |= Arg2.flags_o&O_COMPLEX;
			   continue;
			} else return(lptr);

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
	  
	    case MOD:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			if (Arg1->value_o == 0) break;
			/*if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;*/
			Arg1->value_o %= Arg2.value_o;
			Arg1->flags_o |= Arg2.flags_o & O_COMPLEX;
			continue;

	    case BAN:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			/*if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;*/
			Arg1->value_o &= Arg2.value_o;
			Arg1->flags_o |= Arg2.flags_o & O_COMPLEX;
			continue;
	    case BOR:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			/*if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;*/
			Arg1->value_o |= Arg2.value_o;
			Arg1->flags_o |= Arg2.flags_o & O_COMPLEX;
			continue;


	    case BXO:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			/*if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;*/
			Arg1->value_o ^= Arg2.value_o;
			Arg1->flags_o |= Arg2.flags_o & O_COMPLEX;
			continue;

	    case DIV:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			if (Arg1->value_o == 0) break;
			/*if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;*/
			Arg1->value_o /= Arg2.value_o; /* integer division */
			Arg1->flags_o |= Arg2.flags_o & O_COMPLEX;
			continue;

	    case SHL:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			/*if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;*/
			Arg1->value_o = Arg1->value_o<<(Arg2.value_o % REGSIZE);
			Arg1->flags_o |= Arg2.flags_o & O_COMPLEX;
			continue;

	    case SHR:	lptr = term(++lptr,&Arg2);
			if (Arg1->type_o==t_reg || Arg2.type_o==t_reg) break;
			if (Arg1->sym_o || Arg2.sym_o) break;
			/*if (Arg2.sym_o) Arg1->sym_o = Arg2.sym_o;*/
			Arg1->value_o = Arg1->value_o>>(Arg2.value_o % REGSIZE);
			Arg1->flags_o |= Arg2.flags_o & O_COMPLEX;
			continue;

	    default:	return(lptr);
	  }
	Prog_Error(E_RELOP);
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
	char token[SYMLENGTH];

	/*skipb(lptr);*/
	i = cinfo[*lptr];
        
	if (i == RP) return(lptr);

	if (*lptr == '*') goto sym;

#	ifdef davy
	fprintf(stderr,"Evaluating term...%c\n",*lptr);
#	endif

	/* here for number */
	if (i & D) {

#	  ifdef dave1
	  fprintf(stderr,"Term is a number...\n");
#	  endif

	  p = lptr;
	  if (*lptr == '0') {
	    lptr++;
	    if (*lptr=='x' || *lptr=='X') { lptr++; base = 16; }
	    else base = 8;
	  }
	  else if (*lptr == '$') { 
		lptr++; 
#		ifdef dave1
		fprintf(stderr,"Oops! Thinks it's hex!!!\n");
#		endif
	  
		base = 16; } /* allow $ to specify hex */
	  val = 0;
	  if (base == 16) while (1) {
	    if (cinfo[*lptr] & D) val = val*16 + *lptr++ - '0';
	    else if (*lptr>='A' && *lptr<='F')
	      val = val*16 + *lptr++ - 'A' + 10;
	    else if (*lptr>='a' && *lptr<='f')
	      val = val*16 + *lptr++ - 'a' + 10;
	    else break;
	  } else while ((cinfo[*lptr] & D) && (*lptr != '$')) val = val*base + *lptr++ - '0';

#	  ifdef dave1
	  fprintf(stderr,"Before chk for local label lptr = %d\n",*lptr);
#	  endif

          if (*lptr == '$') { lptr = p; goto sym; } 

	  Vp->value_o = val;
	  Vp->sym_o = NULL;
	  Vp->type_o = t_normal;
	  return(lptr);
	}  /* end of if (i&D) */

	/* here for symbol name */
	if (i & S) {

    sym:  p = token;

#	  ifdef dave1
	  fprintf(stderr,"Term is a symbol...\n");
	  fprintf(stderr,"token: ");
#	  endif

	  if (*lptr == '*') 
	  {

#	  	ifdef arthur
		fprintf(stderr,"%c",*lptr);
#		endif

		*p++ = *lptr++;
		goto lookup;
	  }

	  while ((cinfo[*lptr] & T) && !(*lptr=='.')) {

#	  ifdef dave1
	  fprintf (stderr,"%c",*lptr);
#	  endif
	  				*p++ = *lptr++;} /*end of while*/
  lookup:                                    
#	  ifdef dave1
	  fprintf(stderr,"\n");
#	  endif

	  *p = 0;	  

#	  ifdef junk
	  fprintf(stderr,"**********************************\n");
	  fprintf(stderr,"entering Lookup with %s\n",token);
	  dump_symtab();
	  fprintf(stderr,"----------------------------------\n");
# 	  endif

	  sbp = Lookup(token);		/* find its symbol bucket */



#	  ifdef arthur
	  if (sbp == Dot_bkt) fprintf(stderr,"Its a dot bucket");
	  else fprintf(stderr,"It aint a dot bucket\n");
#	  endif
	  
#	  ifdef debug3
	  printf("sbp->attr_s = %o\n",sbp->attr_s);
	  printf("sbp->attr_s & S_DEF = %o\n",(sbp->attr_s & S_DEF));
#	  endif

	  if (sbp->attr_s & S_DEF)	/* if it's defined, use its value */ 
	  {
	    Vp->value_o = sbp->value_s;
#	    ifdef debug2
	    fprintf(stderr,"in term. value_o set to value_s=%d\n",sbp->value_s);
#	    endif
	  }
	  else  
	  {
#	    ifdef debug2
	    printf(stderr,"in term. value_o set to ZERO\n");
#	    endif
	    Vp->value_o = 0;
	  }

	  if (sbp->attr_s & S_REG) Vp->type_o = t_reg;
	  else {
	    if ((sbp->attr_s & S_DEF) && (sbp->csect_s == 0 || (sbp->csect_s->attr_cs & R_ABS))) Vp->sym_o=0;
	    else Vp->sym_o=sbp;
	    Vp->type_o = t_normal;
	  }
	  return(lptr);
	}

	/* check for unary minus */
	if (i == SUB) {

#	  ifdef Annette
	  fprintf(stderr,"Term's a unary minus...\n");
#	  endif

	  lptr = term(++lptr,Vp);
	  if (Vp->sym_o) Prog_Error(E_RELOCATE);

#	  ifdef Annette
	  fprintf(stderr,"value = %x\n",Vp->value_o);
#	  endif

	  Vp->value_o = -(Vp->value_o);	/* and finally do it */

#	  ifdef Annette
	  fprintf(stderr,"value = %x\n",Vp->value_o);
#	  endif

	  return(lptr);
	}

	/* check for complement */
	if (i == NOT) {
#ifdef debug
printf("Term's a complement...\n");
#endif
	  lptr = term(++lptr,Vp);
	  if (Vp->sym_o) Prog_Error(E_RELOCATE);
	  Vp->value_o = ~(Vp->value_o);	/* and finally do it */
	  return(lptr);
	}

	/* here for string */
	if (i == QUO) {
#ifdef debug
printf("Term is a string...\n");
#endif
	  Vp->value_o = (long)(lptr+1);
	  do i = cinfo[*++lptr]; while (i!=EOL && i!=QUO);
	  *lptr++ = 0;
	  Vp->sym_o = NULL;
	  Vp->type_o = t_string;
	  return(lptr);
	}

	if (i == LP) return(lptr);

#ifdef debug
printf("OOPS! Fell thru!!!\n");
#endif
	Prog_Error(E_TERM);
	return(lptr);
}


char *tnames[] = {
  "?", "reg", "defer", "postinc", "predec", "displ",
  "index", "abss", "absl", "immed", "normal", "string"
};

/*
printop(o)
  register struct oper *o;
  {	fprintf(stderr,"operand %d: type=%s ",numops,tnames[o->type_o]);
	if (o->sym_o)
	  fprintf(stderr,"csect=%s sym=%s ",
		  o->sym_o->csect_s->name_cs,o->sym_o->name_s);
	fprintf(stderr,"value=%ld reg=%d displ=%ld\n",
	 	 o->value_o,o->reg_o,o->disp_o);
  }
*/


/* listsrc - displays pc value and hex code image when -a flag set. */
listsrc()
{
	register short i;
	register unsigned short *WCode = (unsigned short *)Code;

#ifdef debug
fprintf(stderr,"Here is A_file");
fprintf(stderr,A_file);
#endif

	fprintf(A_file, "%04x\t", Dot);
	for (i = 0; i < BC/2; i++) 
		fprintf(A_file, "%04x", (unsigned int)WCode[i]);
	if (i < 2) putc('\t', A_file);
	if (i < 4) putc('\t', A_file);
	else putc(' ',A_file);
	fprintf(A_file, "%s", iline);
}

char *Mask(p,val)

register char *p;
register int *val;
{
    register int mask = 0;
    while (1)
	{
	switch (*p) 
		{
		case 'a':  ++p;		/* it's an addr register */

			   switch (*p)
				{
				case '0':   mask |= 256;	/*bit 8*/
					    p++;
					    break;

				case '1':   mask |= 512; 	/*bit 9*/
					    p++;
					    break;

				case '2':   mask |= 1024;	/*bit 10*/
					    p++;
					    break;

				case '3':   mask |= 2048;	/*bit 11*/
					    p++;
					    break;

				case '4':   mask |= 4096;	/*bit 12*/
					    p++;
					    break;

				case '5':   mask |= 8192;	/*bit 13*/
					    p++;
					    break;

				case '6':   mask |= 16384;	/*bit 14*/
					    p++;
					    break;

				case '7':   mask |= 32768;	/*bit 15*/
					    p++;
					    break;

				default:    Prog_Error(E_BADCHAR);
					    p = NULL;
					    break;
				}
			   break;       /* end of addr reg case */

		case 'd':  ++p;        	/* it's a data register */
			   
			   switch (*p)
				{
				case '0':   mask |= 1; 		/*bit 0*/
					    p++;
					    break;

				case '1':   mask |= 2;	 	/*bit 1*/
					    p++;
					    break;

				case '2':   mask |= 4;		/*bit 2*/
					    p++;
					    break;

				case '3':   mask |= 8;		/*bit 3*/
					    p++;
					    break;

				case '4':   mask |= 16;		/*bit 4*/
					    p++;
					    break;

				case '5':   mask |= 32;		/*bit 5*/
					    p++;
					    break;

				case '6':   mask |= 64;		/*bit 6*/
					    p++;
					    break;

				case '7':   mask |= 128;	/*bit 7*/
					    p++;
					    break;

				default:    Prog_Error(E_BADCHAR);
					    p = NULL;
					    break;
				}
			   break;		/* end of data reg case */

		case '>':  break;

		default:   Prog_Error(E_BADCHAR);  /* has to be d or a reg */
			   break;

		}             	/* end of switch for register type */

	if (*p == '>') 
		{
		p++;
		*val = mask;
		return(p);
		}

	else if (*p != ',') Prog_Error(E_BADCHAR); 
	p++;

    }  /* end of while */

}  /* end of Mask() */

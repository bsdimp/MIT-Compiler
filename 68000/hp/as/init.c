#include "mical.h"
#include "inst.h"

extern int transport;		/* flag to accept pascal psuedoops */
extern int inclptr;
extern FILE *infile;
/* char Title[STR_MAX]; */	/* MFM */
char O_outfile = 0;		/* 1 if .rel file name is specified by user */
int Pass = 0;			/* which pass we're on */
char Rel_name[STR_MAX];		/* Name of .rel file */
FILE *Rel_file;			/* and ptr to it */
char A_name[STR_MAX];		/* Name of listing file */
FILE *A_file;			/* and ptr to it */
struct sym_bkt *Dot_bkt ;	/* Ptr to location counter's symbol bucket */
long tsize = 0;			/* sizes of three main csects */
long dsize = 0;
long bsize = 0;
short aflag;
struct ins_bkt *ins_hash_tab[HASH_MAX];


/* List of 68000 op codes */              /* This list changed 6/9/82 to
					     accomodate motorola opcodes
							      -- ANNY */
struct ins_init { char *opstr; short opnum; }  op_codes[] = {
	"abcd", 	i_abcd,
	"add",		i_addw,
	"add.b",	i_addb,		
	"add.w",	i_addw,		
	"add.l",	i_addl,
	"adda",		i_addw,
	"adda.w",	i_addw,		
	"adda.l",	i_addl,		
	"addi",		i_addw,
	"addi.b",	i_addb,	
	"addi.w",	i_addw,	
	"addi.l",	i_addl,	
	"addq",		i_addqw,	
	"addq.b",	i_addqb,	
	"addq.w",	i_addqw,	
	"addq.l",	i_addql,	
	"addx",		i_addxw,
	"addx.b",	i_addxb,	
	"addx.w",	i_addxw,	
	"addx.l",	i_addxl,	
	"and",		i_andw,
	"and.b",	i_andb,		
	"and.w",	i_andw,		
	"and.l",	i_andl,		
	"andi",		i_andw,
	"andi.b",	i_andb,	
	"andi.w",	i_andw,	
	"andi.l",	i_andl,	
	"asl",		i_aslw,
	"asl.b",	i_aslb,		
	"asl.w",	i_aslw,		
	"asl.l",	i_asll,		
 	"asr",		i_asrw,
	"asr.b",	i_asrb,		
	"asr.w",	i_asrw,		
	"asr.l",	i_asrl,		
	"bcc",		i_bcc,		
	"bcc.s",	i_bccs,		
	"bchg",		i_bchg,		
	"bclr",		i_bclr,		
	"bcs",		i_bcs,		
	"bcs.s",	i_bcss,		
	"beq",		i_beq,		
	"beq.s",	i_beqs,		
	"bge",		i_bge,		
	"bge.s",	i_bges,		
	"bgt",		i_bgt,		
	"bgt.s",	i_bgts,		
	"bhi",		i_bhi,		
	"bhi.s",	i_bhis,		
	"ble",		i_ble,		
	"ble.s",	i_bles,		
	"bls",		i_bls,		
	"bls.s",	i_blss,		
	"blt",		i_blt,		
	"blt.s",	i_blts,		
	"bmi",		i_bmi,		
	"bmi.s",	i_bmis,		
	"bne",		i_bne,		
	"bne.s",	i_bnes,		
	"bpl",		i_bpl,		
	"bpl.s",	i_bpls,		
	"bra",		i_bra,		
	"bra.s",	i_bras,		
	"bset",		i_bset,		
	"bset.s",	i_bsets,	
	"bsr",		i_bsr,		
	"bsr.s",	i_bsrs,		
	"btst",		i_btst,		
	"bvc",		i_bvc,		
	"bvc.s",	i_bvcs,		
	"bvs",		i_bvs,		
	"bvs.s",	i_bvss,		
	"chk",		i_chk,		
	"clr",		i_clrw,
	"clr.b",	i_clrb,		
	"clr.w",	i_clrw,		
	"clr.l",	i_clrl,	
	"cmp",		i_cmpw,
	"cmp.b",	i_cmpb,		
	"cmp.w",	i_cmpw,		
	"cmp.l",	i_cmpl,		
	"cmpa",		i_cmpw,
	"cmpa.w",	i_cmpw,		
	"cmpa.l",	i_cmpl,		
	"cmpi",		i_cmpw,
	"cmpi.b",	i_cmpb,	
	"cmpi.w",	i_cmpw,	
	"cmpi.l",	i_cmpl,	
	"cmpm",		i_cmpmw,
	"cmpm.b",	i_cmpmb,	
	"cmpm.w",	i_cmpmw,	
	"cmpm.l",	i_cmpml,	
	"dbcc",		i_dbcc,		
	"dbcs",		i_dbcs,		
	"dbeq",		i_dbeq,		
	"dbf",		i_dbf,		
	"dbra",		i_dbra,		
	"dbge",		i_dbge,		
	"dbgt",		i_dbgt,		
	"dbhi",		i_dbhi,		
	"dble",		i_dble,		
	"dbls",		i_dbls,		
	"dblt",		i_dblt,		
	"dbmi",		i_dbmi,		
	"dbne",		i_dbne,		
	"dbpl",		i_dbpl,		
	"dbt",		i_dbt,		
	"dbvc",		i_dbvc,		
	"dbvs",		i_dbvs,		
	"divs",		i_divs,		
	"divu",		i_divu,		
	"eor",		i_eorw,		
	"eor.b",	i_eorb,		
	"eor.w",	i_eorw,		
	"eor.l",	i_eorl,		
	"eori",		i_eoriw,
	"eori.b",	i_eorib,	
	"eori.w",	i_eoriw,	
	"eori.l",	i_eoril,	
	"exg",		i_exg,		
	"ext",		i_extw,
	"ext.w",	i_extw,		
	"ext.l",	i_extl,		
	"jbsr",		i_jbsr,
	"jcc",		i_jcc,
	"jcs",		i_jcs,
	"jeq",		i_jeq,
	"jge",		i_jge,
	"jgt",		i_jgt,
	"jhi",		i_jhi,
	"jle",		i_jle,
	"jls",		i_jls,
	"jlt",		i_jlt,
	"jmi",		i_jmi,
	"jmp",		i_jmp,
	"jne",		i_jne,
	"jpl",		i_jpl,
	"jra",		i_jra,
	"jsr",		i_jsr,
	"jvc",		i_jvc,
	"jvs",		i_jvs,
	"lea",		i_lea,		
	"link",		i_link,		
	"lsl",		i_lslw,
	"lsl.b",	i_lslb,		
	"lsl.w",	i_lslw,		
	"lsl.l",	i_lsll,		
	"lsr",		i_lsrw,
	"lsr.b",	i_lsrb,		
	"lsr.w",	i_lsrw,		
	"lsr.l",	i_lsrl,		
	"move",		i_movw,		
	/* move (for move sr, move cc, etc.) */
	"move.b",	i_movb,	
	"move.w",	i_movw,		
	"move.l",	i_movl,		
	"movea",	i_movw,
	"movea.w",	i_movw,		
	"movea.l",	i_movl,
	"movem",	i_movemw,
	"movem.w",	i_movemw,	
	"movem.l",	i_moveml,	
	"movep",	i_movepw,
	"movep.w",	i_movepw,	
	"movep.l",	i_movepl,	
	"moveq",	i_moveq,	
	"muls",		i_muls,	
	"mulu",		i_mulu,		
	"nbcd",		i_nbcd,		
	"neg",		i_negw,
	"neg.b",	i_negb,		
	"neg.w",	i_negw,		
	"neg.l",	i_negl,		
	"negx",		i_negxw,
	"negx.b",	i_negxb,	
	"negx.w",	i_negxw,	
	"negx.l",	i_negxl,	
	"nop",		i_nop,	
	"not",		i_notw,
	"not.b",	i_notb,		
	"not.w",	i_notw,		
	"not.l",	i_notl,		
	"or.b",		i_orb,		
	"or.w",		i_orw,		
	"or.l",		i_orl,		
	"or",		i_orw,		
	"ori",          i_orw,
	"ori.b",	i_orb,		
	"ori.w",	i_orw,		
	"ori.l",	i_orl,		
	"pea",		i_pea,		
	"reset",	i_reset,	
	"rol",		i_rolw,
	"rol.b",	i_rolb,		
	"rol.w",	i_rolw,		
	"rol.l",	i_roll,		
	"ror",		i_rorw,
	"ror.b",	i_rorb,		
	"ror.w",	i_rorw,		
	"ror.l",	i_rorl,		
	"roxl",		i_roxlw,
	"roxl.b",	i_roxlb,	
	"roxl.w",	i_roxlw,	
	"roxl.l",	i_roxll,	
	"roxr",		i_roxrw,
	"roxr.b",	i_roxrb,	
	"roxr.w",	i_roxrw,	
	"roxr.l",	i_roxrl,	
	"rte",		i_rte,		
	"rtr",		i_rtr,		
	"rts",		i_rts,		
	"sbcd",		i_sbcd,		
	"scc",		i_scc,		
	"scs",		i_scs,		
	"seq",		i_seq,		
	"sf",		i_sf,		
	"sge",		i_sge,		
	"sgt",		i_sgt,		
	"shi",		i_shi,		
	"sle",		i_sle,		
	"sls",		i_sls,		
	"slt",		i_slt,		
	"smi",		i_smi,		
	"sne",		i_sne,		
	"spl",		i_spl,		
	"st",		i_st,		
	"stop",		i_stop,		
	"sub",		i_subw,
	"sub.b",	i_subb,		
	"sub.w",	i_subw,		
	"sub.l",	i_subl,		
	"suba",		i_subw,
	"suba.w",	i_subw,		
	"suba.l",	i_subl,
	"subi",		i_subw,
	"subi.b",	i_subb,	
	"subi.w",	i_subw,	
	"subi.l",	i_subl,	
	"subq.b",	i_subqb,	
	"subq.w",	i_subqw,	
	"subq.l",	i_subql,	
	"subq",		i_subqw,	
	"subx",		i_subxw,
	"subx.b",	i_subxb,	
	"subx.w",	i_subxw,	
	"subx.l",	i_subxl,	
	"svc",		i_svc,		
	"svs",		i_svs,		
	"swap",		i_swap,		
	"tas",		i_tas,		
	"trap",		i_trap,		
	"trapv",	i_trapv,	
	"tst",		i_tstw,
	"tst.b",	i_tstb,		
	"tst.w",	i_tstw,		
	"tst.l",	i_tstl,		
	"unlk",		i_unlk,		
	"equ",		i_equal,	
	"dc.b",		i_dcb,		
	"dc.w",		i_dcw,
	"dc.l",		i_dcl,		
	"dc",		i_dcw,
	".long",	i_long,
	".word",	i_word,
	".byte",	i_byte,
	".text",	i_text,
	".data", 	i_data,
	".bss",		i_bss,
	".globl",	i_globl,
	".comm", 	i_comm,
	".even",	i_even,
	".asciz",	i_asciz,
	".ascii",	i_ascii,
	"decimal",	i_null,
	"end",		i_null,
	"llen",		i_null,
	"list",		i_null,
	"lprint",	i_null,
	"nolist",	i_null,
	"noobj",	i_null,
	"nosyms",	i_null,
	"page",		i_null,
	"spc",		i_null,
	"sprint",	i_null,
	"start",	i_null,
	"ttl",		i_null,
	"refa",		i_refa,
	".refa",	i_refa,
	"refr",		i_refr,
	".refr",	i_refr,
	".include",	i_include,
	0 };


char *Source_name = NULL;

Init(argc,argv)
char *argv[];
{
	char *strncpy();				/* MFM */
	register char *cp1, *cp2;			/* MFM */
	register int extnm = 0;

	transport = 0;	/* accept some pascal psuedo ops flag */
	inclptr = -1;

	argv++;
	while (--argc > 0) {
	  if (argv[0][0] == '-') switch (argv[0][1]) {
	    case 'A':	aflag++;  /* list pc and hex bytes on file A_name*/
			Concat(A_name, "stderr", "");
			break;
	    case 'a':	aflag++;  /* list pc and hex bytes on file A_name*/
			Concat(A_name,&argv[0][2],"");
			break;
	    case 'o':	O_outfile++;
			Concat(Rel_name,argv[1],"");
			argv++;			
			argc--;
			break;
	    case 't':	transport=1;    /* accept pascal psuedoops */
			break;
	    case 'p':   extnm=1;	/* recognize ?register names */
			break;
	    default:	fprintf(stderr,"Unknown option '%c' ignored.\n",argv[0][1]);
	  } else if (Source_name != NULL) {
	    fprintf(stderr,"Too many file names given\n");
	  } else {
	    Source_name = argv[0];
	    if ((infile = fopen(Source_name,"r")) == NULL) { /* open source file */
		fprintf(stderr,"Can't open source file: %s\n",Source_name);
		exit(1);
	    }
	  }
	  argv++;
	}


/* Check to see if we can open output file */
	if(!O_outfile)
	{
		if (getsuf(Source_name)=='s')	/* copy basename without suffix to Rel_name */
		{
			cp1 = Source_name;
			cp2 = Rel_name;
			while ((*cp2++ = *cp1++) != '.')
			strcpy(cp2, OBJ_SUFFIX);/* append suffix to basename */
		}
		else Concat(Rel_name,Source_name,OBJ_SUFFIX);
	}
	if ((Rel_file = fopen(Rel_name,"w")) == NULL)
	{	printf("Can't create output file: %s\n",Rel_name);
		exit(1);
	}
	fclose(Rel_file);	/* Rel_Header will open properly */
	if (aflag)
		if (A_name && strcmp(A_name, "stderr")) {
			if ((A_file = fopen(A_name, "w")) == NULL) {
				printf("Can't create listing file: %s\n",
					A_name);
				exit(1);
				}
			}
		else A_file = stderr;

/* Initialize symbols */
	Sym_Init();
	Dot_bkt = Lookup("*");		/* make bucket for location counter */
	Dot_bkt->csect_s = Cur_csect;
	Dot_bkt->attr_s = S_DEC | S_DEF | S_LABEL; 	/* "S_LABEL" so it cant be redefined as a label */
	init_regs(extnm);			/* define register names */
	d_ins();			/* set up opcode hash table */
	Perm();
	Start_Pass();
}

d_ins()
{	register struct ins_init *p;
	register struct ins_bkt *insp;
	register int save;

	for (p = op_codes; p->opstr != 0; p++) {
		insp = (struct ins_bkt *)calloc(1,sizeof(struct ins_bkt));
		insp->text_i = p->opstr;
		insp->code_i = p->opnum;
		insp->next_i = ins_hash_tab[save = Hash(insp->text_i)];
		ins_hash_tab[save] = insp;
	}
}

struct def { char *rname; int rnum; } defregs[] = {
  "d0", 0, "d1", 1, "d2", 2, "d3", 3, "d4", 4, "d5", 5, "d6", 6, "d7", 7,
  "a0", 8, "a1", 9, "a2", 10, "a3", 11, "a4", 12, "a5", 13, "a6", 14, "a7", 15,
  "sp", 15, "pc", 16, "cc", 17, "sr", 18, "usp", 19,
  0, 0
};
struct def xrfrgs[] = {
  "?d0", 0, "?d1", 1, "?d2", 2, "?d3", 3, "?d4", 4, "?d5", 5, "?d6", 6, "?d7", 7,
  "?a0", 8, "?a1", 9, "?a2", 10, "?a3", 11, "?a4", 12, "?a5", 13, "?a6", 14, "?a7", 15,
  "?sp", 15, "?pc", 16, "?cc", 17, "?sr", 18, "?usp", 19,
  0, 0
};

init_regs(extnm)   register int extnm;
  {	register struct sym_bkt *sbp;
	register struct def *p;
	struct sym_bkt *Lookup();

	p = (extnm) ? xrfrgs : defregs;

	while (p->rname) {
	  sbp = Lookup(p->rname);	/* Make a sym_bkt for it */
	  sbp->value_s = p->rnum;	/* Load the sym_bkt */
	  sbp->csect_s = 0;
	  sbp->attr_s = S_DEC | S_DEF | S_REG;
	  p++;
	}
}

Concat(s1,s2,s3)
  register char *s1,*s2,*s3;
  {	while (*s1++ = *s2++);
	s1--;
	while (*s1++ = *s3++);
}


/*
 * Return the ptr in sp at which the character c last
 * appears; NULL if not found
*/

#define NULL 0


/*
 * Copy s2 to s1, truncating or null-padding to always copy n bytes
 * return s1
 */

char *
strncpy(s1, s2, n)
register char *s1, *s2;
{
	register short i;
	register char *os1;

	os1 = s1;
	for (i=n; i > 0; i--)
		if ((*s1++ = *s2++) == '\0') {
			while (i-- > 0)
				*s1++ = '\0';
			return(os1);
		}
	return(os1);
}


getsuf(as)
char as[];
{
	register short c = 0;
	register short t;
	register char *s = as;

	while (t = *s++)
		if (t == '/') c = 0;
		else c++;
	s -= 3;
	if ((c <= DIRSIZ) && (c>2) && (*s++ == '.')) return (*s);
	return (0);
}

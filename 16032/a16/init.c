#include "mical.h"

char Title[STR_MAX];
char O_outfile = 0;		/* 1 if .rel file name is specified by uder */
int Pass = 0;			/* which pass we're on */
char Rel_name[STR_MAX];		/* Name of .rel file */
FILE *Rel_file;			/* and ptr to it */
struct sym_bkt *Dot_bkt ;	/* Ptr to location counter's symbol bucket */
long tsize = 0;			/* sizes of three main csects */
long dsize = 0;
long bsize = 0;
struct ins_bkt *ins_hash_tab[HASH_MAX];

int lflag;


/* List of 16032 op codes */
int	i_long(), i_word(), i_byte();
int	i_text(), i_data(), i_bss();
int	i_globl();
int	i_comm();
int	i_even();
int	i_ascii(), i_asciz();
int	i_zerol();

struct	opcode  optable[] = {

#include "optable"

{ ".long", -1, (long)i_long },
{ ".word", -1, (long)i_word },
{ ".byte", -1, (long)i_byte },
{ ".text", -1, (long)i_text },
{ ".data", -1, (long)i_data },
{ ".bss", -1, (long)i_bss },
{ ".globl", -1, (long)i_globl },
{ ".comm", -1, (long)i_comm },
{ ".even", -1, (long)i_even },
{ ".ascii", -1, (long)i_ascii },
{ ".asciz", -1, (long)i_asciz },
{ ".zerol", -1, (long)i_zerol },

};


char *Source_name = NULL;
char File_name[STR_MAX];

Init(argc,argv)
char *argv[];
{	register int i,j;
	char *strncpy();
	char *cp1, *cp2, *end, *rindex();

	argv++;
	while (--argc > 0) {
	  if (argv[0][0] == '-') switch (argv[0][1]) {
	    case 'o':	O_outfile++;
			Concat(Rel_name,argv[1],"");
			argv++;			
			argc--;
			break;

	    case 'l':	lflag++;
			break;

	    default:	fprintf(stderr,"Unknown option '%c' ignored.\n",argv[0][1]);
	  } else if (Source_name != NULL) {
	    fprintf(stderr,"Too many file names given\n");
	  } else {
	    Source_name = argv[0];
	    Concat(File_name, argv[0], ".a16");
	    if (freopen(File_name,"r",stdin) == NULL) {/* open source file */
	      if ((end = rindex(Source_name, '.')) == 0 ||
			strcmp(end, ".a16") != 0) {
	        fprintf(stderr,"Can't open source file: %s\n",File_name);
	        exit(1);
	      }
	      strncpy(File_name, argv[0], STR_MAX);
	      if (freopen(File_name,"r",stdin) == NULL) {/* open source file */
	        fprintf(stderr,"Can't open source file: %s\n",File_name);
	        exit(1);
	      }
	    }
	  }
	  argv++;
	}


/* Check to see if we can open output file */
	if(!O_outfile)
	{
		if ((end = rindex(Source_name, '.')) == 0 ||
			strcmp(end, ".a16") != 0)
			Concat(Rel_name,Source_name,".b");
		else	/* copy basename without .a68 to Rel_name */
		{
			for (cp1 = Source_name, cp2 = Rel_name; cp1 < end;)
				*cp2++ = *cp1++;
			strcpy(cp2, ".b");	/* append ".b" to basename */
		}
	}
	if ((Rel_file = fopen(Rel_name,"w")) == NULL)
	{	printf("Can't create output file: %s\n",Rel_name);
		exit(1);
	}
	fclose(Rel_file);	/* Rel_Header will open properly */

/* Initialize symbols */
	Sym_Init();
	Dot_bkt = Lookup(".");		/* make bucket for location counter */
	Dot_bkt->csect_s = Cur_csect;
 	/* "S_LABEL" so it cant be redefined as a label */
	Dot_bkt->attr_s = S_DEC | S_DEF1|S_DEF2 | S_LABEL;
	init_regs();			/* define register names */
	d_ins();			/* set up opcode hash table */
	Perm();
	Start_Pass();
}

d_ins()
{	register struct opcode *p;
	register struct ins_bkt *insp;
	register int save;

	for(p = &optable[0] ;
	    p < &optable[sizeof(optable)/sizeof(optable[0])] ;
	    p++) {
		insp = (struct ins_bkt *)calloc(1,sizeof(struct ins_bkt));
		insp->text_i = p->op_name;
		insp->code_i = p;
		insp->next_i = ins_hash_tab[save = Hash(insp->text_i)];
		ins_hash_tab[save] = insp;
	}
}

struct def { char *rname; int rnum; } defregs[] = {
	/* general registers */
	".r0", 0,	".r1", 1,	".r2", 2,	".r3", 3,
	".r4", 4,	".r5", 5,	".r6", 6,	".r7", 7,
	/* special registers */
	".fp", 8,	".sp", 9,	".sb", 10,	".pc", 11,
	".tos", 12,
	/* processor registers */
	".psr", 13,	".intbase", 14,	".mod", 15,	".upsr", 16,
	/* memory managment registers */
	".bpr0", 32,	".bpr1", 33,	".pf0", 36,	".pf1", 37,
	".sc", 40,	".msr", 42,	".bcnt", 43,
	".ptb0", 44,	".ptb1", 45,	".eia", 47,
	0, 0
};

init_regs()
  {	register struct sym_bkt *sbp;
	register struct def *p = defregs;
	struct sym_bkt *Lookup();

	while (p->rname) {
	  sbp = Lookup(p->rname);	/* Make a sym_bkt for it */
	  sbp->value_s = p->rnum;	/* Load the sym_bkt */
	  sbp->csect_s = 0;
	  sbp->attr_s = S_DEC | S_DEF1|S_DEF2 | S_REG;
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

char *
rindex(sp, c)
register char *sp, c;
{
	register char *r;

	r = NULL;
	do {
		if (*sp == c)
			r = sp;
	} while (*sp++);
	return(r);
}


/*
 * Copy s2 to s1, truncating or null-padding to always copy n bytes
 * return s1
 */

char *
strncpy(s1, s2, n)
register char *s1, *s2;
{
	register i;
	register char *os1;

	os1 = s1;
	for (i = 0; i < n; i++)
		if ((*s1++ = *s2++) == '\0') {
			while (++i < n)
				*s1++ = '\0';
			return(os1);
		}
	return(os1);
}

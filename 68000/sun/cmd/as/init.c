#include "mical.h"
#include "inst.h"
#ifndef Stanford
#include <bootstrap.h>
#define	HEADER	"/include/as.h"
#endif Stanford

#define TRUE	1
#define FALSE	0

char	header[64], Title[STR_MAX];

/* Command line options */
char	O_list = 0;	/* 1 if listing requested */
char	*O_listname = 0;/* name of listing file if -L option is used */
char	O_symtab = 0;	/*1 if symbol table desired */
char	O_debug = 0;	/* >0 if debugging desired */
char	O_ext_only = 0;	/* 1 if external symbols only in .rel file */
char	O_print = 0;	/* 1 if listing printed on terminal */
char	O_global = 0;	/* 1 if undefined symbols are to be made global */
char	O_outfile = 0;	/* 1 if .rel file name is specified by user */

/*
 *
The source stack. Ss_top contains the subscript of the top of
the stack, which then points to the iobuffer of the current input source file 
 *
 */

FILE *Source_stack[SSTACK_MAX+1];
int Ss_top = -1;				/* Source stack top */
int		Pass = 0;			/* initialize Pass. */
char		File_name[STR_MAX];
char		Temp_name[STR_MAX];		/* Name of temporary file to hold source between passes 1 and 2 */
FILE		*Temp_file;			/* Ptr to iobuf of that file */
char		Rel_name[STR_MAX];		/* Name of .rel file */
FILE		*Rel_file;			/* and ptr to it */
FILE		*listout;			/* file to write listings to */
struct sym_bkt	*Dot_bkt ;	/* Ptr to location counter's symbol bucket */

struct op_entry {
	char *op_name;
	int op_number;};

struct op_entry op_codes[] = {	/* List of 68000 op codes */
	"abcd",	i_abcd,
	"addb",	i_addb,
	"addw",	i_addw,
	"addl",	i_addl,
	"addqb",	i_addqb,
	"addqw",	i_addqw,
	"addql",	i_addql,
	"addxb",	i_addxb,
	"addxw",	i_addxw,
	"addxl",	i_addxl,
	"andb",	i_andb,
	"andw",	i_andw,
	"andl",	i_andl,
	"aslb",	i_aslb,
	"aslw",	i_aslw,
	"asll",	i_asll,
	"asrb",	i_asrb,
	"asrw",	i_asrw,
	"asrl",	i_asrl,
	"bcc",	i_bcc,
	"bccs",	i_bccs,
	"bchg",	i_bchg,
	"bclr",	i_bclr,
	"bcs",	i_bcs,
	"bcss",	i_bcss,
	"beq",	i_beq,
	"beqs",	i_beqs,
	"bge",	i_bge,
	"bges",	i_bges,
	"bgt",	i_bgt,
	"bgts",	i_bgts,
	"bhi",	i_bhi,
	"bhis",	i_bhis,
	"ble",	i_ble,
	"bles",	i_bles,
	"bls",	i_bls,
	"blss",	i_blss,
	"blt",	i_blt,
	"blts",	i_blts,
	"bmi",	i_bmi,
	"bmis",	i_bmis,
	"bne",	i_bne,
	"bnes",	i_bnes,
	"bpl",	i_bpl,
	"bpls",	i_bpls,
	"bra",	i_bra,
	"bras",	i_bras,
	"bset",	i_bset,
	"bsr",	i_bsr,
	"bsrs",	i_bsrs,
	"btst",	i_btst,
	"bvc",	i_bvc,
	"bvcs",	i_bvcs,
	"bvs",	i_bvs,
	"bvss",	i_bvss,
	"chk",	i_chk,
	"clrb",	i_clrb,
	"clrw",	i_clrw,
	"clrl",	i_clrl,
	"cmpb",	i_cmpb,
	"cmpw",	i_cmpw,
	"cmpl",	i_cmpl,
	"cmpmb",	i_cmpmb,
	"cmpmw",	i_cmpmw,
	"cmpml",	i_cmpml,
	"dbcc",	i_dbcc,
	"dbcs",	i_dbcs,
	"dbeq",	i_dbeq,
	"dbf",	i_dbf,
	"dbra",	i_dbra,
	"dbge",	i_dbge,
	"dbgt",	i_dbgt,
	"dbhi",	i_dbhi,
	"dble",	i_dble,
	"dbls",	i_dbls,
	"dblt",	i_dblt,
	"dbmi",	i_dbmi,
	"dbne",	i_dbne,
	"dbpl",	i_dbpl,
	"dbt",	i_dbt,
	"dbvc",	i_dbvc,
	"dbvs",	i_dbvs,
	"divs",	i_divs,
	"divu",	i_divu,
	"eorb",	i_eorb,
	"eorw",	i_eorw,
	"eorl",	i_eorl,
	"exg",	i_exg,
	"extw",	i_extw,
	"extl",	i_extl,
	"jbsr", i_jbsr,
	"jcc",	i_jcc,
	"jcs",	i_jcs,
	"jeq",	i_jeq,
	"jge",	i_jge,
	"jgt",	i_jgt,
	"jhi",	i_jhi,
	"jle",	i_jle,
	"jls",	i_jls,
	"jlt",	i_jlt,
	"jmi",	i_jmi,
	"jmp",	i_jmp,
	"jne",	i_jne,
	"jpl",	i_jpl,
	"jra",	i_jra,
	"jsr",	i_jsr,
	"jvc",	i_jvc,
	"jvs",	i_jvs,
	"lea",	i_lea,
	"link",	i_link,
	"lslb",	i_lslb,
	"lslw",	i_lslw,
	"lsll",	i_lsll,
	"lsrb",	i_lsrb,
	"lsrw",	i_lsrw,
	"lsrl",	i_lsrl,
	"movb",	i_movb,
	"movw",	i_movw,
	"movl",	i_movl,
	"movemw",	i_movemw,
	"moveml",	i_moveml,
	"movepw",	i_movepw,
	"movepl",	i_movepl,
	"moveq",	i_moveq,
	"muls",	i_muls,
	"mulu",	i_mulu,
	"nbcd",	i_nbcd,
	"negb",	i_negb,
	"negw",	i_negw,
	"negl",	i_negl,
	"negxb",	i_negxb,
	"negxw",	i_negxw,
	"negxl",	i_negxl,
	"nop",	i_nop,
	"notb",	i_notb,
	"notw",	i_notw,
	"notl",	i_notl,
	"orb",	i_orb,
	"orw",	i_orw,
	"orl",	i_orl,
	"pea",	i_pea,
	"reset",	i_reset,
	"rolb",	i_rolb,
	"rolw",	i_rolw,
	"roll",	i_roll,
	"rorb",	i_rorb,
	"rorw",	i_rorw,
	"rorl",	i_rorl,
	"roxlb",	i_roxlb,
	"roxlw",	i_roxlw,
	"roxll",	i_roxll,
	"roxrb",	i_roxrb,
	"roxrw",	i_roxrw,
	"roxrl",	i_roxrl,
	"rte",	i_rte,
	"rtr",	i_rtr,
	"rts",	i_rts,
	"sbcd",	i_sbcd,
	"scc",	i_scc,
	"scs",	i_scs,
	"seq",	i_seq,
	"sf",	i_sf,
	"sge",	i_sge,
	"sgt",	i_sgt,
	"shi",	i_shi,
	"sle",	i_sle,
	"sls",	i_sls,
	"slt",	i_slt,
	"smi",	i_smi,
	"sne",	i_sne,
	"spl",	i_spl,
	"st",	i_st,
	"stop",	i_stop,
	"subb",	i_subb,
	"subw",	i_subw,
	"subl",	i_subl,
	"subqb",	i_subqb,
	"subqw",	i_subqw,
	"subql",	i_subql,
	"subxb",	i_subxb,
	"subxw",	i_subxw,
	"subxl",	i_subxl,
	"svc",	i_svc,
	"svs",	i_svs,
	"swap",	i_swap,
	"tas",	i_tas,
	"trap",	i_trap,
	"trapv",	i_trapv,
	"tstb",	i_tstb,
	"tstw",	i_tstw,
	"tstl",	i_tstl,
	"unlk",	i_unlk,
	0 };

/*
 *
 Init is the primary routine of this file. It is called by the top level (main) to process the arguments of the command line.
 *
 */

int canum = 1;			/* command argument number */

Init(argc,argv)
char *argv[];
{
	register char *cp;
	register int i,j;
	FILE *src;	/* ptr to iobufs for source and descriptor files */
	struct sym_bkt *Lookup();
	extern struct csect *Cur_csect;	/* ptr to current csect */

	if (argc < 2 ) {
		printf("usage:	as68 [-godspel] sourcefilename\n"); exit(1);
	}
	Options(argv);			/* get options, leaves argv[canum] */
					/* as the first unoptioned command */
					/* argument, and presumably the source filename */

/* get source file name */

	for (i=0; Title[i]=argv[canum][i]; i++);	/* copy filename */
	Concat(File_name,argv[canum],".s");
	if ((src = fopen(File_name,"r")) == NULL)	/* open source file */
	{
	  Concat(File_name,argv[canum],".a68");
	  if ((src = fopen(File_name,"r")) == NULL)	/* try .a68 extension */
	  {
	    Concat(File_name,argv[canum],"");
	    if ((src = fopen(File_name,"r")) == NULL)	/* try without .s */
	    {
		printf("Can't open source file: %s.s\n",File_name);
		exit(1);
	    }
	  }
	} else canum++;

	Options(argv);
	Push_Source(src);		/* push the input file onto the source stack */

/* Open default header file */
#ifdef Stanford
	if ((src = fopen("/usr/sun/lib/a68.hdr","r")) != NULL) Push_Source(src);
#else Stanford
	strcpy (header, ROOT);
	strcat (header, HEADER);
	if ((src = fopen(header,"r")) != NULL) Push_Source(src);
#endif Stanford

/* Open temporary output file */
	Concat(Temp_name,Title,".temp");
	if ((Temp_file = fopen(Temp_name,"w")) == NULL)
	{
		printf("Can't create output file: %s\n",Temp_name);
		return(FALSE);
	}

/* Open listing file, if necessary */
	if (O_list)
	{
		char List_name[STR_MAX];
		Concat(List_name, Title, ".list");
		if ((listout = fopen(O_listname?O_listname:List_name, "w"))
		     == NULL)
		{
			printf("Can't create listing file: %s\n", List_name);
			return(FALSE);
		}
	}

/* Check to see if we can open output file */
	if(!O_outfile)
		Concat(Rel_name,Title,".b");
	if ((Rel_file = fopen(Rel_name,"w")) == NULL)
	{	printf("Can't create output file: %s\n",Rel_name);
		return(FALSE);
	}
	fclose(Rel_file);	/* Rel_Header will open properly */

/* Initialize symbols */
	Sym_Init();
	Dot_bkt = Lookup(".");		/* make bucket for location counter */
	Dot_bkt->csect_s = Cur_csect;
	Dot_bkt->attr_s = S_DEC | S_DEF | S_LABEL; 	/* "S_LABEL" so it cant be redefined as a label */
	Init_Macro();			/* initialize macro package */
	d_ins();			/* set up opcode hash table */
	return(TRUE);
}

d_ins()
{
	register struct ins_bkt *insp;
	register int i,save;

	i = 0;
	while (op_codes[i].op_name) {
		insp = (struct ins_bkt *) malloc(sizeof ins_example);	/* allocate ins_bkt */
		insp->text_i = op_codes[i].op_name;	/* pointer to asciz op code */
		insp->code_i = op_codes[i++].op_number;	/* index for dispatching */
		insp->next_i = ins_hash_tab[save = Hash(insp->text_i)];	/* ptr to ins_bkt */
		ins_hash_tab[save] = insp;
	}
	return(TRUE);
}


/* Routine to push a ptr to an iobuffer on the "source stack". The top of the
 * stack points to the buffer of the current source file. src is the io buffer ptr.
 */
Push_Source(src)
FILE *src;
{
	register int top;

	if (++Ss_top >= SSTACK_MAX) 	/* Get stack top, complain if invalid. (will exit) */
		Sys_Error("Source stack overflow: %d",top); 
	Source_stack[Ss_top] = src;
}


/* Reads options on command line. *ap is a ptr to the index of the current argument */
Options(argv)
char **argv;
{
	register char *cp;
	
	while(argv[canum][0] == '-'){
		for (cp = &argv[canum++][1];*cp;cp++) switch(*cp){
			case 'd':	O_debug = 1;
					if (*(cp+1)>='0' && *(cp+1)<='9') 
						O_debug = *(++cp) - '0';
					break;
			case 'p':	O_print = 1; break;
			case 'e':	O_ext_only = 1; break;
			case 'L':	O_listname = argv[canum++];
			case 'l':	O_list = 1;  break;
			case 's':	O_symtab= 1; break;
			case 'g':	O_global = 1; break;
			case 'o':	O_outfile = 1;
					if(argv[canum])
					  Concat(Rel_name, argv[canum++], "");
					break;
			default:	printf("Unknown option  '%c' ignored.\n",*cp);
		}
	}
}


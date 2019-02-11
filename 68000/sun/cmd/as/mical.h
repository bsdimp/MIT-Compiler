#ifdef BOOTSTRAP
#include "/usr/include/stdio.h"
#else
#include <stdio.h>
#endif

/* Assembler parameters */
#define	STR_MAX		32	/* number of chars in any single token */
#define OPERANDS_MAX	4	/* number of operands allowed per instruction */
#define MNEM_MAX	8	/* number of chars in instruction mnemonic */
#define	LINE_MAX	132	/* Number of chars in input line */
#define	FILEID_MAX	15	/* number of files open at any one time */
#define	HASH_MAX	32	/* size of symbol, command, and macro hash tables */
#define	CONT_MAX	3	/* number of chars in control field of operand */
#define CODE_MAX	12	/* number of bytes generated for 1 machine instruction */
#define SSTACK_MAX	10	/* Max number of input source files open at any time */
#define ERR_MAX		50	/* Max number of different error codes */
#define CSECT_MAX	200	/* number of control sections */
#define COND_MAX	16	/* maximum depth of nested conditional blocks */

/* Error Codes */
#define E_END		1
#define E_BADCHAR	2
#define E_MULTSYM	3
#define	E_NOSPACE	4
#define	E_OFFSET	5
#define	E_SYMLEN	6
#define	E_SYMDEF	7
#define	E_CONSTANT	8
#define	E_TERM		9
#define	E_OPERATOR	10
#define	E_RELOCATE	11
#define	E_TYPE		12
#define	E_OPERAND	13
#define	E_SYMBOL	14
#define	E_EQUALS	15
#define	E_NLABELS	16
#define	E_OPCODE	17
#define	E_ENTRY		18
#define	E_STRING	19
#define	E_INSRT		20
#define	E_ATTRIBUTE	21
#define	E_.ERROR	22
#define	E_LEVELS	23
#define	E_CONDITION	24
#define	E_NUMOPS	25
#define	E_LINELONG	26
#define E_REG		27
#define	E_IADDR		28
#define E_UNIMPL	29
#define E_FILE		30
#define E_MLENGTH	32
#define E_MACARG	33
#define	E_MACFORMAL	34
#define E_ENDC		35
#define E_RELADDR	36
#define E_ARGUMENT	37
#define E_VECINDEX	38
#define E_VECMNEM	39
#define E_MACRO		40
#define E_TMACRO	41
#define E_CSECT		42
#define E_ODDADDR	43
/* Size Codes - These should agree with Rel size codes in b.h */

#define B 0	/* byte */
#define W 1	/* word */
#define L 2	/* long */


/* Print Codes */

#define	P_ALL		0
#define P_LC		1
#define P_NONE		2


/* Symbol attributes */

#define	S_DEC	01
#define S_DEF	02
#define S_EXT	04
#define S_LABEL	010
#define S_MACRO	020
#define S_REG	040
#define S_LOCAL 0100
#define S_COMM	0200
#define S_PERM	0400

/* Rel file and Csect attributes */
#define R_EXT	01
#define R_ISPC	02
#define R_PURE	04
#define R_ABS	010
#define R_DEC	020

/* Operand flags */
#define O_WINDEX 1
#define O_LINDEX 2
#define O_COMPLEX 4

/* Abbreviations */
#define FLAG	char
#define TRUE	1
#define FALSE	0
#define true	1
#define false	0


/* operand types */

#define t_reg	1
#define t_defer	2
#define t_postinc	3
#define t_predec	4
#define t_displ	5
#define t_index	6
#define	t_abss	7
#define t_absl	8
#define t_immed 9
#define t_normal 10
/* Instruction Hash Table */

struct ins_bkt {
	struct ins_bkt	*next_i;	/* ptr to next bkt  on the list */
	char		*text_i;	/* ptr to asciz instruction mnemonic */
	int 		code_i;		/* opcode index for dispatching */
	} ins_example;			/* example of ins_bkt, used for sizeof operation */

/* The instruction hash table itself. Each entry is the head of a linearly linked list
 * of ins_bkts.
 */
	struct ins_bkt *ins_hash_tab[HASH_MAX];

/* Csect descriptor */
	struct csect {
		char	*name_cs;	/* Name, usually stored with Store_String */
		long	len_cs;		/* Length in machine addresses, i.e., highest address referenced */
		long	dot_cs;		/* current dot in this cs, in machine addresses */
		int	id_cs;		/* ID # for output file */
		int	attr_cs;	/* attributes */
	} ;



/* Symbol bucket definition */
	struct sym_bkt{
		struct sym_bkt	*next_s;	/* next bkt on linked list */
		char		*name_s;	/* symbol identifier */
		long		value_s;	/* it's value */
		int		id_s;		/* id number for .rel file */
		struct csect	*csect_s;	/* ptr to it's csect */
		int		attr_s;		/* attributes */
	} ;

/* Code[], buffer for the generated code */ 
char Code[CODE_MAX];

struct oper {
 char type_o;			/* operand type info */
 char flags_o;			/* operand flags */
 char reg_o;			/* Register subfield value */
 struct sym_bkt *sym_o;		/* symbol used for relocation */
 long value_o;			/* Value subfield */
 long disp_o;			/* displacement value for index mode */
} Operand ;



/* VIP variables */

int	Pass ;			/* Pass number */
long	Dot ;			/* Assembly location counter */
char	Line[LINE_MAX+1];	/* buffer for source statement */
int	Position ;		/* current position in Line */
int	BC;			/* Byte count of current line */
long	tsize;			/* size of the text segment, valid on pass2 */
long	dsize;			/* size of the data segment */
long	bsize;			/* size of the bss segment */


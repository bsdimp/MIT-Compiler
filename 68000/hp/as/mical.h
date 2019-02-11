
#include <stdio.h>
#include <globaldefs.h>
#include <a.out.h>

/* Assembler parameters */
#define	STR_MAX		256	/* number of chars in any single token */
#define OPERANDS_MAX	16	/* number of operands allowed per instruction */
#define	HASH_MAX	256	/* size of symbol, command, and macro hash tables */
#define CODE_MAX	12	/* number of bytes generated for 1 machine instruction */
#define ERR_MAX		50	/* Max number of different error codes */
#define CSECT_MAX	200	/* number of control sections */
#define Csect_load	4	/* Previously a variable. Next available Csect */
#define LSIZE		200	/* max size of input line */


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
#define E_GLOBL		44
#define E_RELOP		45
#define E_TEXTALIGN	46
#define E_REGLIST	47

#define MAXERR		30

/* Size Codes - These should agree with Rel size codes in b.h */
#define B 0	/* byte */
#define W 1	/* word */
#define L 2	/* long */

#define A 3	/* align - special flag */

/* operand flags */
#define O_WINDEX 1
#define O_LINDEX 2
#define O_COMPLEX 4

/* Symbol attributes */
#define	S_DEC	01      /* has been declared */
#define S_DEF	02      /* has been defined */
#define S_EXT	04      /* is external */
#define S_LABEL	010     /* is a label */
#define S_MACRO	020     /* represents a macro operation */
#define S_REG	040     /* represents a machine register */
#define S_LOCAL 0100    /* is local to a block */
#define S_COMM	0200    /* is declared in COMMON */  
#define S_PERM	0400
#define S_ALIGN 01000	/* for .align psuedo-op */
#define S_RELATIVE	02000   	/*anny -- means rel undefable and ext*/
#define S_CANTDEFINE	04000		/*anny -- means undefinable*/

/* Rel file and Csect attributes */
#define R_EXT	01
#define R_ISPC	02
#define R_PURE	04
#define R_ABS	010
#define R_DEC	020
               
		          /* Possible 68000 addressing */
/* operand types */       /* modes for each oprnd type */ 

#define t_reg	1         /* register direct */
#define t_defer	2         /* register indirect */
#define t_postinc	3 /* register indirect w/ postincrement */
#define t_predec	4 /* register indirect w/ predecrement */
#define t_displ	5         /* register indirect (or pc relatve) w/ displacemnt */
#define t_index	6         /* register indirect (or pc relative) w/ index */
#define	t_abss	7         /* absolute short */
#define t_absl	8         /* absolute long */
#define t_immed 9         /* immediate operand */
#define t_normal 10       /* God only knows . . . */
#define t_string 11

int transport;		/* flag to tell if we're accepting some pascal psudos */

/* Instruction Hash Table */
struct ins_bkt {
  struct ins_bkt *next_i;	/* ptr to next bkt on the list */
  char *text_i;			/* ptr to asciz instruction mnemonic */
  short code_i;			/* opcode index for dispatching */
};

/* Csect descriptor */
struct csect {
  char *name_cs;	/* name */
  long len_cs;		/* Length in machine addresses, i.e., highest address referenced */
  long dot_cs;		/* current dot in this cs, in machine addresses */
  short id_cs;		/* ID # for output file */
  short attr_cs;	/* attributes */
};

/* Symbol bucket definition */
struct sym_bkt {
  char *name_s;			/* symbol identifier */
  struct sym_bkt *next_s;	/* next bkt on linked list */
  struct csect *csect_s;	/* ptr to it's csect */
  long value_s;			/* it's value */
  short id_s;			/* id number for .o file */
  short attr_s;			/* attributes */
  short modulo_s;		/* used only for .align syms; it stores the
				   modulo value */
};

/* operand structure */
struct oper {
  char type_o;			/* operand type info */
  char flags_o;			/* operand flags */
  char reg_o;			/* Register subfield value */
  struct sym_bkt *sym_o;	/* symbol used for relocation */
  long value_o;			/* Value subfield */
  long disp_o;			/* displacement value for index mode */
};

extern char *soperand(),*exp();
extern char iline[],Code[];
extern short cinfo[];
extern int numops,Errors,Line_no,Pass,BC;
extern struct oper operands[];
extern struct ins_bkt *ins_hash_tab[];
extern struct sym_bkt *Lookup();
extern struct sym_bkt *Dot_bkt;
extern struct sym_bkt *Last_symbol;
extern long Dot,tsize,dsize,bsize;
extern struct csect *Cur_csect,*Text_csect,*Data_csect,*Bss_csect;
extern struct csect Csects[];
extern char Rel_name[],*Source_name;
extern short *WCode;		/* buffer for code in ins.c */
extern char Code_length;	/* number of bytes in WCode */

/* skip to next non-spacing character */
#define skipb(p) while (cinfo[*p] == SPC) p++

/* skip to end of symbol */
#define skips(p) while (cinfo[*p] & T) p++

/* bits found in character info array cinfo[] */
#define D 0x0100	/* digit */
#define S 0x0200	/* can start symbol */
#define T 0x0400	/* can be part of symbol */

#define COL 0x00	/* label definition */
#define EQL 0x01	/* label assignment */
#define EOL 0x02	/* end of line -- newline or comment char */
#define ADD 0x03	/* addition operator */
#define SUB 0x04	/* subtraction operator */
#define SPC 0x05	/* spacing character */
#define ERR 0x06	/* illegal character */
#define IMM 0x07	/* immediate operand indicator */
#define LP  0x08	/* left paren */
#define RP  0x09	/* right paren */
#define COM 0x0A	/* operand separator */
#define MUL 0x0C	/* multiplication operator */
#define NOT 0x0D	/* complement operator */
#define QUO 0x0E	/* beginning/end of string */
#define BAN 0x10	/* bitwise and operator */
#define BOR 0x11	/* bitwise or operator */
#define BXO 0x12	/* bitwise exclusive or operator */
#define DIV 0x13	/* integer div operator */
#define MOD 0x14	/* integer mod operator */
#define SHL 0x15	/* shift left operator */
#define SHR 0x16	/* shift right operator - sign bit extended */

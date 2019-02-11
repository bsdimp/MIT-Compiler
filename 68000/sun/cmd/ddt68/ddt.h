/* ddt.h 
 */

#include "b.out.h"

#define LITSYMS			/* this must agree with dl68 */
#define BPMAX		8	/* number of breakpoints allowed */
#define BADARG		'*'	/* bad command */
#define ESCCHR		''	/* argument delimiter */
#define BPINST		0x4E4E	/* trap #14 instruction */
#define TRACEBIT	0x8000	/* trace bit in status register */
#define DEFRADIX	16	/* default radix */
#define MAXSYMLEN	10	/* maximum length of symbol */
				/*** must agree with dl68 ***/

/* type-out structure for the disassembler */
struct cbuffr {
	char buf[40];		/* the output buffer */
	int pnt;		/* pointer into output buffer */
	int col;		/* output column # */
	};

/* Type field definitions */
#define CHARTYPE	0x01	/* character type */
#define BYTETYPE	0x02	/* byte */
#define WORDTYPE	0x03	/* word */
#define LONGTYPE	0x04	/* long */
#define INSTTYPE	0x05	/* instruction */
#define STRTYPE		0x06	/* string */
#define TYPEFIELDMASK	0x07	/* mask for type field */

#define SIGNEDTYPE	0x08	/* basic signed type */
#define POINTERTYPE	0x10	/* pointer to something */
#define USERTYPE	0x20	/* user-defined type */
#define DDTSYM		0x80	/* symbol is an internal ddt symbol */
#define DEFTOMODE	INSTTYPE

/*
 * structure of a symbol table definition
 */
typedef struct Symtabdef {
	struct sym *start;
	struct sym *limit;
	} symtabdef;

#ifdef DM
#define USRSYMS		(symtabdef *) 0x570 /* pointer to start of symbols */
#else
extern symtabdef ddtusrsyms;
#define USRSYMS		(&ddtusrsyms)
#endif DM

#ifdef MC68000
#define ADJ 2 & -2
#define getbpc(pc)	*(char *)(pc)
#define putbpc(pc, byte) *(char *)(pc) = (char) (byte)
#define getwpc(pc)	*(short *) (pc)
#define putwpc(pc, word) *(short *)(pc) = (short) (word)
#define getlpc(pc)	*(long *) (pc)
#define putlpc(pc, llong) *(long *)(pc) = (long) (llong)

#else ndef MC68000
#define ADJ 1
extern getbpc();
extern void putbpc();
extern short getwpc();
extern void putwpc();
extern long getlpc();
extern void putlpc();
#endif MC68000

/* breakpoint mechanism */
struct bpstr {
	short *pc;		/* pc at breakpoint */
	short oldinst;		/* old instruction */
	short count;		/* proceed counter */
	};

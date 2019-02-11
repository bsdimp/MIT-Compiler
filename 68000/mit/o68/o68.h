#include <stdio.h>

/*
 * Header for object code improver
 */

#define	JBR	1
#define	CBR	2
#define	JMP	3
#define	LABEL	4
#define	DLABEL	5
#define	EROU	6
#define	MOV	7
#define	CLR	8
#define	NOT	9
#define	ADDQ	10
#define	SUBQ	11
#define	NEG	12
#define	TST	13
#define	ASR	14
#define	ASL	15
#define LSR	16
#define LSL	17
#define	EXT	18
#define	CMP	20
#define	ADD	21
#define	SUB	22
#define	AND	23
#define	OR	24
#define	EOR	25
#define LEA	26
#define PEA	27
#define MOVEM	28
#define LINK	29
#define UNLK	30
#define	JSR	31
#define	TEXT	32
#define	DATA	33
#define	BSS	34
#define	EVEN	35
#define	END	36
#define JSW	37
#define MOVEQ	38
#define MULS	39
#define MULU	40
#define DIVS	41
#define DIVU	42

#define	JEQ	0
#define	JNE	1
#define	JLE	2
#define	JGE	3
#define	JLT	4
#define	JGT	5
#define	JLO	6
#define	JHI	7
#define	JLOS	8
#define	JHIS	9

#define	BYTE	100
#define WORD	101
#define LONG	102

struct node {
	char	op;
	char	subop;
	struct	node	*forw;
	struct	node	*back;
	struct	node	*ref;
	int	labno;
	char	*code;
	int	refc;
};

struct optab {
	char	*opstring;
	int	opcode;
} optab[];

char	line[1024];
struct	node	first;
struct	node	*freenodes;
char	*curlp;
int	nbrbr;
int	nsaddr;
int	redunm;
int	iaftbr;
int	njp1;
int	nrlab;
int	nxjump;
int	ncmot;
int	nrevbr;
int	loopiv;
int	nredunj;
int	nskip;
int	ncomj;
int	nsob;
int	nrtst;
int	nlit;

int	nchange;
int	isn;
int	debug;
char	*lasta;
char	*lastr;
char	*firstr;
char	revbr[];
char	regs[16][20];
char	conloc[20];
char	conval[20];
char	ccloc[20];

#define	RT1	14
#define	RT2	15
#define	NREG	14
#define	LABHS	127
#define	OPHS	57

struct optab *ophash[OPHS];
struct { char lbyte; };

extern char *copy();
extern char *findcon();
extern struct node *getnode();
extern struct node *nonlab();
extern struct node *codemove();
extern struct node *insertl();

/*	This file must be maintained in:
 *
 *		/trix/include/b.out.h
 *		/include/b.out.h
 *
 *	Layout of b.out file :
 *
 *	header of 8 longs	magic number 405, 407, 410, 411
 *				text size		)
 *				data size		) in bytes
 *				bss size		)
 *				symbol table size	)
 *				text relocation size	)
 *				data relocation size	)
 *				entry point
 *
 *
 *	header:			0
 *	text:			32
 *	data:			32+textsize
 *	symbol table:		32+textsize+datasize
 *	text relocation:	32+textsize+datasize+symsize
 *	data relocation:	32+textsize+datasize+symsize+rtextsize
 *
 */
/* various parameters */
#define SYMLENGTH	50		/* maximum length of a symbol */
#define PAGESIZE	1024		/* relocation boundry for 410 files */

/* types of files */
#define	ARCMAGIC 0177545
#define OMAGIC	0405
#define	FMAGIC	0407
#define	NMAGIC	0410
#define	IMAGIC	0411

/* symbol types */
#define	EXTERN	(040<<8)
#define	UNDEF	(00<<8)
#define	ABS	(01<<8)
#define	TEXT	(02<<8)
#define	DATA	(03<<8)
#define	BSS	(04<<8)
#define	COMM	(05<<8)	/* internal use only */
#define REG	(06<<8)

/*	char rsegment:2;	/* RTEXT, RDATA, RBSS, or REXTERN */
/*	char rsize:2;		/* RBYTE, RWORD, or RLONG */
/*	char rdisp:1;		/* 1 => a displacement */

/* displacement */
#define	RDISP	(1<<(3+8))

/* relocation segments */
#define	RSEGMNT	(03<<(6+8))

#define	RTEXT	(00<<(6+8))
#define	RDATA	(01<<(6+8))
#define	RBSS	(02<<(6+8))
#define	REXT	(03<<(6+8))

/* relocation sizes */
#define	RSIZE	(03<<(4+8))

#define RBYTE	(00<<(4+8))
#define RWORD	(01<<(4+8))
#define RLONG	(02<<(4+8))

/* macros which define various positions in file based on a bhdr, filhdr */
#define TEXTPOS		sizeof(filhdr)
#define DATAPOS 	TEXTPOS + filhdr.tsize
#define SYMPOS		DATAPOS + filhdr.dsize
#define RTEXTPOS	SYMPOS + filhdr.ssize
#define RDATAPOS	RTEXTPOS + filhdr.rtsize
#define ENDPOS		RDATAPOS + filhdr.rdsize
/* header of b.out files */
struct bhdr {
	long	fmagic;
	long	tsize;
	long	dsize;
	long	bsize;
	long	ssize;
	long	rtsize;
	long	rdsize;
	long	entry;
};

/* symbol management */
struct sym {
	short	stype;
	long	svalue;
};

/* relocation commands */
struct reloc {
	short rinfo;		/* rsegment, rsize, and rdisp */
/*	char rsegment:2;	/* RTEXT, RDATA, RBSS, or REXTERN */
/*	char rsize:2;		/* RBYTE, RWORD, or RLONG */
/*	char rdisp:1;		/* 1 => a displacement */
	short rsymbol;		/* id of the symbol of external relocations */
	long rpos;		/* position of relocation in segment */
};

/* Stuff for unix compatibility */

#define	A_MAGIC1	FMAGIC       	/* normal */
#define	A_MAGIC2	NMAGIC       	/* read-only text */

struct	nlist {	/* symbol table entry */
	char    	n_name[8];	/* symbol name */
	int     	n_type;    	/* type flag */
	unsigned	n_value;	/* value */
};

		/* values for type flag */
#define	N_UNDF	0	/* undefined */
#define	N_ABS	01	/* absolute */
#define	N_TEXT	02	/* text symbol */
#define	N_DATA	03	/* data symbol */
#define	N_BSS	04	/* bss symbol */
#define	N_TYPE	037
#define	N_REG	024	/* register name */
#define	N_FN	037	/* file name symbol */
#define	N_EXT	040	/* external bit, or'ed in */
#define	FORMAT	"%06o"	/* to print a value */

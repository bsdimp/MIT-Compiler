/*
 *
 *	Layout of a.out file :
 *
 *	header  		short magic number 0405, 0407, 0410, 0411
 *				short configuration	~set by user
 *				long reserved hp spare
 *				short machine stamp	~ set by machine
 *				short DSTD size		) in # entries
 *				long text size		)
 *				long data size		) in bytes
 *				long bss size		)
 *				long text relocation size)
 *				long data relocation size)
 *				long MIS size		)
 *				long LEST size 		)
 *				long DST size		)
 *				long entry point
 *				long spare field 1
 *				long spare field 2
 *				long spare field 3
 *				long spare field 4
 *
 *
 *
 *	header:			0
 *	text:			sizeof(header)
 *	data:			sizeof(header)+textsize
 *	MIS:			sizeof(header)+textsize+datasize
 *	LEST:			sizeof(header)+textsize+datasize+ 
 *				MISsize 
 *	DSTD			sizeof(header)+textsize+datasize+
 *				MISsize+LESTsize
 *	DST			sizeof(header)+textsize+datasize+
 *				MISsize+LESTsize+dstdir*sizeof(dstd_entry)
 *	text relocation:	sizeof(header)+textsize+datasize+
 *				MISsize+LESTsize+dstdir*sizeof(dstd_entry)+
 *				dstsize
 *	data relocation:	sizeof(header)+textsize+datasize+
 *				MISsize+LESTsize+dstdir*sizeof(dstd_entry)+
 *				dstsize+rtextsize
 *				rtextsize
 *
 */

#ifndef KERNEL

/* various parameters */
#define SYMLENGTH	255		/* maximum length of a symbol */
#define PAGESIZE	1024		/* relocation boundry for 410 files */

/* types of files */
#define	ARCMAGIC 0177545
#define OMAGIC	0405	/* unknown magic number MFM */
#define	FMAGIC	0407	/* = 0x107 readable,writable,not shared, data contig */
#define	NMAGIC	0410	/* = 0x108 sharable, not writable, data on block bdry */
#define	IMAGIC	0411	/* not writable, sharable, pdp11 only */

/* symbol types */
#define	EXTERN	040	/* = 0x20 */
#define ALIGN	020	/* = 0x10 */	/* special alignment symbol type */
#define	UNDEF	00
#define	ABS	01
#define	TEXT	02
#define	DATA	03
#define	BSS	04
#define	COMM	05	/* internal use only */
#define REG	06

/* relocation regions */
#define	RTEXT	00
#define	RDATA	01
#define	RBSS	02
#define	REXT	03

/* relocation sizes */
#define RBYTE	00
#define RWORD	01
#define RLONG	02
#define RALIGN	03	/* special reloc flag to support .align symbols */

/* macros which define various positions in file based on an exec: filhdr */
#define TEXTPOS		sizeof(filhdr)
#define DATAPOS 	TEXTPOS + filhdr.a_text
#define MODCALPOS	DATAPOS + filhdr.a_data
#define LESYMPOS	MODCALPOS + filhdr.a_modcal /* mit = SYMPOS */
#define DSTDPOS		LESYMPOS + filhdr.a_lesyms
#define DSTPOS		DSTDPOS + (filhdr.a_dstdir * sizeof(struct dstdentry))
#define RTEXTPOS	DSTPOS + filhdr.a_dsyms
#define RDATAPOS	RTEXTPOS + filhdr.a_trsize

#endif

/* header of a.out files */
struct exec {		/* mit = bhdr */
		short	a_magic;
		short	a_stamp;
		long	a_sparehp;
		short	a_machine;
		short	a_dstdir;
		long	a_text;
		long	a_data;
		long	a_bss;
		long	a_trsize;
		long	a_drsize;
		long	a_modcal;
		long	a_lesyms;
		long	a_dsyms;
		long	a_entry;
		long	a_spare1;
		long	a_spare2;
		long	a_spare3;
		long	a_spare4;
};

#ifndef KERNEL

/* symbol management */
struct nlist_ {			/* mit = sym */	/* sizeof(struct nlist)=10 */
	long	n_value;	/* mit = svalue */
	unsigned char	n_type;		/* mit = stype */
	unsigned char	n_length;	/* length of ascii symbol name */
	short	n_unit;		/* symbolic debugging unit number */
	short	n_sdindex;	/* index into DST */
	/*char	n_ascii;*/	/* ascii for symbol name (no \0 trailer) */
	/* NOTE: n_ascii is a variable length array of size n_length */
};

struct dstdentry {
	long	d_tstart;	/* relative pos of text unit to TEXTPOS */
	long	d_dstart;	/* relative pos of data unit to DATAPOS */
	long	d_bstart;	/* relative start of bss unit */
	long	d_mstart;	/* relative start of MIS unit */
	long	d_lesstart;	/* relative start of LEST unit */
	long	d_dststart;	/* relative start of DST unit */
	long	d_dstspare;	/* */
	};

/* NOTE: entries in dstdentry are relative offsets from the actual beginning
   of the major exec segment. (e.g. the first dstdentry in dstdir will always
   have 0 in all fields) */
/* NOTE: at this time there is no d_cstart for relative start of common units
   because I don't see how we can segment common by unit. Common space is
   allocated between the data segment and the bss area by the loader based 
   on the symbol table that is entirely rebuilt during the link editing 
   process (no duplicate entries in common). */

/* relocation commands */
struct r_info {		/* mit= reloc{rpos,rsymbol,rsegment,rsize,rdisp} */
	long r_address;		/* position of relocation in segment */
	short r_symbolnum;	/* id of the symbol of external relocations */
	char r_segment;		/* RTEXT, RDATA, RBSS, or REXTERN */
	char r_length;		/* RBYTE, RWORD, or RLONG */
};

/* Stuff for unix compatibility */

#define	A_MAGIC1	FMAGIC       	/* normal */
#define	A_MAGIC2	NMAGIC       	/* read-only text */

/* These suffixes must also be maintained in the cc shell file */

#define OUT_NAME "a.out"
#define OBJ_SUFFIX ".o"
#define C_SUFFIX ".c"
#define ASM_SUFFIX ".s"
#define MC68000 9836

#ifdef vax
struct	nlist {	/* symbol table entry */
	char    	*n_name;	/* symbol name */
	int     	n_type;    	/* type flag */
	unsigned	n_value;	/* value */
};
#endif

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

#define N_BADMAG(x) (((x).a_magic)!=FMAGIC&&((x).a_magic)!=NMAGIC)

#endif

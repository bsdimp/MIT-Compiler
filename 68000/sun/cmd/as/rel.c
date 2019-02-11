#include "mical.h"
#ifndef Stanford
#include <a.out.h>
#else Stanford
#include "b.out.h"
#endif Stanford

/*  Handle output file processing for b.out files */
/*  V. Pratt Dec 12 1981 incorporated jks fix to Put_Words (cc[1] fix) */

FILE *tout;		/* text portion of output file */
FILE *dout;		/* data portion of output file */
FILE *rtout;		/* text relocation commands */
FILE *rdout;		/* data relocation commands */

long rtsize;		/* size of text relocation area */
long rdsize;		/* size of data relocation area */

char rtname[STR_MAX];	/* name of file for text relocation commands */
char rdname[STR_MAX];	/* name of file for data relocation commands */

#ifndef Stanford
struct exec filhdr;	/* header for b.out files, contains sizes */
#else Stanford
struct bhdr filhdr;	/* header for b.out files, contains sizes */
#endif Stanford

extern struct csect *Bss_csect, *Data_csect, *Text_csect, *Cur_csect;
/* Initialize files for output and write out the header */

Rel_Header()
{
	long Sym_Write();
	extern char *Rel_name;
	extern char EntryFlag, Title[];
	extern struct sym_bkt Entry_point;

	if ((tout = fopen(&Rel_name, "w")) == NULL ||
		(dout = fopen(&Rel_name, "a")) == NULL)
		Sys_Error("open on output file %s failed", &Rel_name);

	Concat(rtname, Title, ".rtmpr");
	if ((rtout = fopen(rtname, "w")) == NULL)
		Sys_Error("open on output file %s failed", rtname);
	Concat(rdname, Title, ".dtmpr");
	if ((rdout = fopen(rdname, "w")) == NULL)
		Sys_Error("open on output file %s failed", rdname);
	filhdr.fmagic = FMAGIC;
	filhdr.tsize = tsize;
	filhdr.dsize = dsize;
	filhdr.bsize = bsize;
	fseek(tout, (long)(SYMPOS), 0);
	filhdr.ssize = Sym_Write(tout);
	filhdr.rtsize = rtsize;
	filhdr.rdsize = rdsize;
	filhdr.entry = EntryFlag? Entry_point.value_s: 0;

	fseek(tout, 0L, 0);
	fwrite(&filhdr, sizeof(filhdr), 1, tout);

	fseek(tout, (long)(TEXTPOS), 0);	/* seek to start of text */
	fseek(dout, (long)(DATAPOS), 0);	
	rtsize = 0;
	rdsize = 0;
}
/*
 * Fix_Rel -	Fix up the object file
 *	For .b files, we have to
 *	1)	append the relocation segments
 *	2)	fix up the rtsize and rdsize in the header
 *	3)	delete the temporary file for relocation commands
 */
Fix_Rel()
{
	long ortsize;
	long i;
	register FILE *fint, *find, *fout;
	ortsize = filhdr.rtsize;
	filhdr.rtsize = rtsize;
	filhdr.rdsize = rdsize;
	fclose(rtout);
	fclose(rdout);
	if ((fint = fopen(rtname, "r")) == NULL)
		Sys_Error("cannot reopen text relocation file %s", rtname);
	if ((find = fopen(rdname, "r")) == NULL)
		Sys_Error("cannot reopen data relocation file %s", rdname);

	fout = tout;

	/* first write text relocation commands */

	fseek(fout, (long)(RTEXTPOS), 0);
	for (i=0; i<rtsize; i++)
		putc(getc(fint), fout);

	for (i=0; i<rdsize; i++)
		putc(getc(find), fout);

	/* now re-write header */

	fseek(fout, 0, 0);
	fwrite(&filhdr, sizeof(filhdr), 1, fout);
	fclose(fint);
	unlink(rtname);
	fclose(find);
	unlink(rdname);
}
/* rel_val -	Puts value of operand into next bytes of Code
 * updating Code_length. Put_Rel is called to handle possible relocation.
 * If size=L a longword is stored, otherwise a word is stored 
 */
rel_val(opnd,size)
register struct oper *opnd;
{
	register int i;
	register struct sym_bkt *sp;
	long val;
	extern int *WCode;		/* buffer for code in ins.c */
	extern char Code_length;	/* number of bytes in WCode */
	char *CCode;			/* char version of this */

	i = Code_length>>1;	/* get index into WCode */
	if (sp = opnd->sym_o)
		Put_Rel(opnd, size, Dot + Code_length);
	val = opnd->value_o;
	switch(size)
	{
	case L:
		WCode[i++] = val>>16;
		Code_length += 2;
	case W:
		WCode[i] = val;
		Code_length += 2;
		break;
	case B:
		CCode = (char *)WCode;
		CCode[Code_length++] = val;
	}
 }
/* Version of Put_Text which puts whole words, thus enforcing the mapping
 * of bytes to words.							 */

Put_Words(code,nbytes)
register char *code;
{	register char *cc, ch;
	register int i,j;
	char tcode[100];

#ifdef BOOTSTRAP
	cc = tcode;
	for (j=i=0; i<nbytes;) 	/*skips over bogus bytes on a vax*/
	  {tcode[i++] = code[j++]; tcode[i++]=code[j++];j+=2;}
	i = nbytes>>1;
	if (nbytes & 1) Sys_Error("Put_Words given odd nbytes=%d\n",nbytes);
	while (i--) { ch = *cc; *cc = *(char*)((int)cc+1); *++cc = ch; cc++; }
	Put_Text(tcode,nbytes);
#else
	cc = tcode;
	for (j=i=0; i<nbytes;)	/*skips over bogus bytes on a 68000*/
	  {j+=2; tcode[i++] = code[j++];tcode[i++]=code[j++];}
	i = nbytes>>1;
	if (nbytes & 1) Sys_Error("Put_Words given odd nbytes=%d\n",nbytes);
	Put_Text(tcode,nbytes);
#endif
}


/* Put_Text -	Write out text to proper portion of file */

Put_Text(code,length)
 register char *code;
 {
	if (Pass != 2) return;
	if (Cur_csect == Text_csect) fwrite(code, length, 1, tout);
	else if (Cur_csect == Data_csect) fwrite(code, length, 1, dout);
	else return;	/* ignore if bss segment */
 }

/* set up relocation word for operand:
 *  opnd	pointer to operand structure
 *  size	0 = byte, 1 = word, 2 = long/address
 *  offset	offset into WCode & WReloc array
 */

Put_Rel(opnd,size,offset)
struct oper *opnd;
int size;
long offset;
{
	struct reloc r;
	if (opnd->sym_o == 0) return;	/* no relocation */
	if (Cur_csect == Text_csect)
		rtsize += rel_cmd(&r, opnd, size, offset, rtout);
	else if (Cur_csect == Data_csect)
		rdsize += rel_cmd(&r, opnd, size, offset - tsize, rdout);
	else return;	/* just ignore if bss segment */
}


/* rel_cmd -	Generate a relocation command and output */

rel_cmd(rp, opnd, size, offset, file)
register struct reloc *rp;
struct oper *opnd;
int size;
long offset;
FILE *file;
{
	int csid;			/* reloc csect identifier */
	register struct csect *csp;	/* pointer to csect of sym */
	register struct sym_bkt *sp;	/* pointer to symbol */

	sp = opnd->sym_o;
	csp = sp->csect_s;
	if (Pass == 2) {
		rp->rsymbol = 0;
		if (!(sp->attr_s & S_DEF)
		 && (sp->attr_s & S_EXT)) {
			rp->rsegment = REXT;
			rp->rsymbol = sp->id_s;
		}
		else if (csp == Text_csect) rp->rsegment = RTEXT;
		else if (csp == Data_csect) rp->rsegment = RDATA;
		else if (csp == Bss_csect) rp->rsegment = RBSS;
		else Prog_Error(E_RELOCATE);
		rp->rpos = offset;
		rp->rsize = size;
		rp->rdisp = 0;
		fwrite(rp, sizeof *rp, 1, file);
	}
	return(sizeof *rp);
}


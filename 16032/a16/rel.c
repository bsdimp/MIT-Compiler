#include "mical.h"
#include <a.out.h>

/*  Handle output file processing for b.out files */

FILE *tout;		/* text portion of output file */
FILE *dout;		/* data portion of output file */
FILE *rtout;		/* text relocation commands */
FILE *rdout;		/* data relocation commands */

long rtsize;		/* size of text relocation area */
long rdsize;		/* size of data relocation area */

char rname[STR_MAX];	/* name of file for relocation commands */

struct exec filhdr;	/* header for object files, contains sizes */

/* Initialize files for output and write out the header */

Rel_Header()
{
	long Sym_Write();

	if((tout = fopen(Rel_name, "w")) == NULL ||
	   (dout = fopen(Rel_name, "a")) == NULL)
		Sys_Error("open on output file %s failed", Rel_name);

	Concat(rname, Source_name, ".tmpr");
	if((rtout = fopen(rname, "w")) == NULL ||
	   (rdout = fopen(rname, "a")) == NULL)
		Sys_Error("open on output file %s failed", rname);

	filhdr.a_magic = OMAGIC;
	filhdr.a_text = tsize;
	filhdr.a_data = dsize;
	filhdr.a_bss = bsize;
	filhdr.a_entry = 0;
	filhdr.a_trsize = rtsize;
	filhdr.a_drsize = rdsize;
	fseek(tout, (long)(N_SYMOFF(filhdr)), 0);
	filhdr.a_syms = Sym_Size();

	fseek(tout, 0L, 0);
	fwrite(&filhdr, sizeof(filhdr), 1, tout);

	fseek(tout, (long)(N_TXTOFF(filhdr)), 0);  /* seek to start of text */
	fseek(dout, (long)(N_DATOFF(filhdr)), 0);  /* seek to start of data */
	fseek(rdout, rtsize, 0);
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
	register FILE *fin, *fout;

	ortsize = filhdr.a_trsize;
	filhdr.a_trsize = rtsize;
	filhdr.a_drsize = rdsize;
	fclose(rtout);
	fclose(rdout);
	if((fin = fopen(rname, "r")) == NULL)
		Sys_Error("cannot reopen relocation file %s", rname);

	fout = tout;

	/* first write text relocation commands */

	fseek(fout, (long)(N_TRLOFF(filhdr)), 0);
	for(i = 0 ; i < rtsize ; i++)
		putc(getc(fin), fout);

	/* seek to start of data segment relocation commands */

	fseek(fin, ortsize, 0);
	for(i=0 ; i < rdsize ; i++)
		putc(getc(fin), fout);

	/* now re-write header */
	fseek(fout, 0, 0);
	fwrite(&filhdr, sizeof(filhdr), 1, fout);
	fclose(fin);
	unlink(rname);
}


/* Put_Text -	Write out text to proper portion of file */

Put_Text(code,length)
register char *code;
{
	if(Pass != 2)
		return;
	if(Cur_csect == Text_csect)
		fwrite(code, length, 1, tout);
	else if(Cur_csect == Data_csect)
		fwrite(code, length, 1, dout);
	/* ignore if bss segment */
}


/* Pad_Text -	Write zero bytes to pad out proper portion of file */

Pad_Text(length)
register length;
{
	register FILE *f;
	if(Pass != 2)
		return;
	if(Cur_csect == Text_csect)
		f = tout;
	else if(Cur_csect == Data_csect)
		f = dout;
	else
		/* ignore if bss segment */
		return;
	while (length-- > 0)
		putc(0, f);
 }


/*
 * set up relocation word for operand:
 *  opnd	pointer to operand structure
 *  size	0 = byte, 1 = word, 2 = long/address
 *  type	0 = normal, 1 = disp, 2 = immed  (| pcrel)
 *  offset	offset into WCode & WReloc array
 */

Put_Rel(sym, size, type, offset)
struct sym_bkt *sym;
int size;
long offset;
{
	struct relocation_info r;

	if(sym == NULL)
		return;	/* no relocation */
	if(Cur_csect == Text_csect)
		rtsize += rel_cmd(&r, sym, size, type, offset, rtout);
	else if(Cur_csect == Data_csect)
		rdsize += rel_cmd(&r, sym, size, type, offset - tsize, rdout);
	/* just ignore if bss segment */
}


/* rel_cmd -	Generate a relocation command and output */

int	rszs[5] = {  -1, 0, 1, -1, 2  };

rel_cmd(rp, sp, size, type, offset, file)
register struct relocation_info *rp;
register struct sym_bkt *sp;	/* pointer to symbol */
int size;
long offset;
FILE *file;
{
	int csid;			/* reloc csect identifier */
	register struct csect *csp;	/* pointer to csect of sym */

	csp = sp->csect_s;
	if(Pass == 2) {
		if(!(sp->attr_s & S_DEF) && (sp->attr_s & S_EXT)) {
			rp->r_extern = 1;
			rp->r_symbolnum = sp->id_s;
		}
		else {
			register int  type;
			rp->r_extern = 0;
			if(!(sp->attr_s&S_DEF))
				type = N_UNDF;
			else if(sp->csect_s == Text_csect)
				type = N_TEXT;
			else if(sp->csect_s == Data_csect)
				type = N_DATA;
			else if(sp->csect_s == Bss_csect)
				type = N_BSS;
			else
				type = N_ABS;
			if(sp->attr_s & S_EXT)
				type |= N_EXT;
			rp->r_symbolnum = type;
		}
		rp->r_address = offset;
		rp->r_pcrel = type&R_PCREL ? 1 : 0;
		rp->r_length = rszs[size];
		rp->r_type = type & 03;
		fwrite(rp, sizeof *rp, 1, file);
	}
	return(sizeof *rp);
}

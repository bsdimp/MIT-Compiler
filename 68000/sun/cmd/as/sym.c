#include "mical.h"
#ifndef Stanford
#include <a.out.h>
#else Stanford
#include "b.out.h"
#endif Stanford

/* Modified by V. Pratt 7/31/81 to include symbol length in table */

#define NLABELS_MAX 10

/* Allocation increments for symbol buckets and character blocks */
#define	SYM_INCR	200
#define CBLOCK_INCR	512

struct sym_bkt	*sym_hash_tab[HASH_MAX];	/* Symbol hash table. */
struct sym_bkt	sym_heap[SYM_INCR];		/* initial heap of sym bkts */
struct sym_bkt	*sym_free;			/* head of free list */
int		Sym_heap_count = 1;		/* number heaps allocated */

char	Cblock[CBLOCK_INCR];			/* used to store texts */
char	*Ccblock = Cblock;			/* ptr to "current" cblock */
int	Cb_nextc = 0;				/* next available char */
int	Cb_count = 1;				/* number blocks allocated */

struct sym_bkt 	*Last_symbol;			/* ptr to last defined symbol*/
struct csect *Data_csect, *Text_csect, *Bss_csect;

/* 
 * Lookup(S)	
 * 	
 *	Input:		char string S
 *	Output:		returns pointer to symbol bucket whose name is S
 *	Purpose:	To place a symbol in the symbol table.
 *	Method:		The symbol table is a hash table, where each entry
 *		is a linearly linked list of symbol buckets.
 *			Local symbols are implemented by just replacing the
 *		'$' at the end of a local symbol with the name of the last
 *		defined label or csect.
 *	Side Effects:	If the symbol S is not on the symbol table, an
 *		entry is made for it.
 */

struct sym_bkt *Lookup(S)
register char *S;
{
	register struct sym_bkt	*sbp;	/* general purpose ptr */
	register int Save;		/* save subscript in sym_hash_tab */
	char	local[STR_MAX];		/* buffer for generated local strings*/
	char	*cp;
	extern char O_debug;
	char *Store_String(),*lastc();
	struct sym_bkt *get_sym_bkt();

	if (S == 0) Sys_Error("Lookup of null symbol");
	if (strcmp(S, " ") == 0) Sys_Error("Bad Symbol");
	if (O_debug >= 9) printf("\n      Lookup: S=%s, ",S);

/* Gen local symbol by replacing final '$' with name of last defined symbol */
	if (*(cp=lastc(S)) == '$') {
		*cp = 0;
		Concat(local,S,Last_symbol->name_s);
		S = local; }		/* pretend we were called with the local symbol itself */
	/* if the symbol is already in here, return a ptr to it */
	for (sbp=sym_hash_tab[Save=Hash(S)]; sbp; sbp = sbp->next_s)
		if (seq(sbp->name_s,S)){
			if (O_debug >= 9) printf("found\n");
			return(sbp); }

	/* Since it's not, make a bucket for it, and put the bucket in the symbol table */
	sbp = get_sym_bkt();			/* get the bucket */
	sbp->name_s = Store_String(S);		/* Store it's name */
	sbp->value_s = NULL;
	sbp->id_s = NULL;
	sbp->csect_s = NULL;
	sbp->attr_s = NULL;
	sbp->next_s = sym_hash_tab[Save];	/* and insert on top of list */
	return(sym_hash_tab[Save] = sbp);
}

/* get_sym_bkt():	Routine to grab a new symbol bucket off of the free list, and allocate space for a new free list if necessary */

struct sym_bkt *get_sym_bkt(){
	register struct sym_bkt	*sbp,	/* general ptr */
			*heap;	/* ptr to array of unused symbol bkts, a "heap" */
	struct sym_bkt	*sym_link();
	extern char O_debug;	/* debugging switch */

	sbp = sym_free;			/* get the first unused sym_bkt from the free list */
	while ((sym_free = sym_free->next_s) == 0) {	/* and move the freelist header down */
	/* if end of free list, allocate a new heap, and link the sym_bkts together to form a new free list */
		if ((heap = (struct sym_bkt *)malloc(sizeof sym_heap)) == 0)
			Sys_Error("Symbol storage exceeded\n",0);
		Sym_heap_count++;
		if (O_debug >=4) printf("--sym heap allocated, #%d --",Sym_heap_count);
		sym_free = sym_link(heap); }
	return(sbp);
}

/* sym_link(heap):	Routine to link the array of sym_bkts "heap" in a linear list. Returns ptr to top of list. 
		It is assumed that the array has SYM_INCR sym_bkts in it */

struct sym_bkt *(sym_link(heap))
struct sym_bkt *heap;
{
	register int i;
	register struct sym_bkt *top;	/* top of list */

	top = 0;			/* zero marks end of list */
	for(i = SYM_INCR-1; i >= 0; --i) {
		heap[i].next_s = top;
		top = &(heap[i]); }
	return(top);
}

/* Sym_Init:	Routine to initialize the first sym_heap */

Sym_Init() { 
	struct sym_bkt *sym_link();
	sym_free = sym_link(sym_heap); 
}




/* Store_String(String):	Routine to store character strings.
 *	MICAL does not have fixed length variable names. This routine allocates
 *  storage in CBLOCK_INCR size chunks, and then sub-allocates space in this 
 *  to hold character strings. S is the char string you want to store 
 *	Returns ptr to the string.
 */

char *Store_String(String)
char *String;
{
	register char  *S;	/* working char string */
	char		*Start;	/* value returned; location of allocated char string */

	Start = &(Ccblock[Cb_nextc]);	/* starting location of allocated char string */
	for(S = String;	 Cb_nextc < CBLOCK_INCR; S++) 	/* load the char string into the current cblock */
		if ((Ccblock[Cb_nextc++] = *S) == 0) return(Start);
	/* overflowed the current character block, so allocate a new one and try again */
	Ccblock = (char *)malloc(CBLOCK_INCR);
	Cb_nextc = 0;
	Cb_count++;
	return(Store_String(String));
}


/* Label()	label and direct assignment handler 
 * 	This routine picks up labels of the form <symbol>: on the source line
 * and enters them in the symbol table. It sets up Label_list, a list of 
 * symbol bucket pointers for the labels in the statement.
 *	In addition, it recognizes direct assignment statements.
 */

struct sym_bkt	*Label_list[NLABELS_MAX];	/* list of sym_bkts for labels on a line */
int		Label_count;			/* number of such symbols */

Label() {
	register struct sym_bkt	*sbp;	/* general ptr */
	int		Save;		/* save Position on Line */
	register char	S[STR_MAX];	/* string to hold symbol name */
	char		Got,		/* 1 if we've picked up a valid symbol yet, 0 otherwise */
			Which,		/* 1 if processing label, 0 if processing direct assignment (d.a.) statement */
			LS,		/* set if local symbol label */
			C;		/* temp char */
	extern int	E_pass1;	/* Error code for non-correctable pass 1 errors */
	extern struct sym_bkt *Last_sym;/* Last symbol defined */
	extern struct csect *Cur_csect;	/* Current csect */
	char *lastc();

	Save = Position;		/* Remember current position */
	Got = 0;			/* We haven't picked up a symbol yet */
	Label_count = Which = 0;
	while (Get_Token(S)){		/* Pick up the first token */
		Got++;			/* Set the flag that says so */
		LS = 0;
		Non_Blank();		/* skip to  first non_blank */
		if ((C = Line[Position]) != ':'  && (C != '=')) break;	/* if we didn't pick up a label, quit trying */
		if (Label_count == 0) {	/* If this is the first symbol we've picked up, */
			Which = (C == ':') ? 1 : 2;	/* Determine which operation we're doing. */
			Got++; }			/* So we don't do this again */
		Position++;				/* move Position past : or = */
							/* check if valid symbol */
		if ((S[0] >= '0') && (S[0] <= '9') && !(LS = (*lastc(S) == '$'))) {	
			Prog_Error(E_SYMBOL); return(TRUE); }
		sbp = Lookup(S);			/* Find the symbol bucket for this symbol */
		if ((Pass==1) && Which==1) {		/* On pass 1, initialize the label's symbol bucket */
			if (sbp->attr_s & S_LABEL)	/* If this label's already defined, complain */
				E_pass1 = E_MULTSYM;
			sbp->attr_s |= S_LABEL | S_DEC | S_DEF;	/* Symbol is a label, it's declared and defined */
			if (LS) sbp->attr_s |= S_LOCAL;	/* mark local symbols as such */
			sbp->csect_s = Cur_csect;		/* it's csect is the current one */
			sbp->value_s = Dot; }			/* it's value is the location counter */
		if (LS == false && Which == 1) Last_symbol = sbp;	/* make Last_symbol last defined label */
		if (sbp->attr_s & S_REG) Prog_Warning(E_MULTSYM);	/* Warn him if he's using a register symbol */
		if (Label_count < NLABELS_MAX)		/* if we don't have too many labels, */
			Label_list[Label_count++] = sbp;	/* put this one on the Label list */
		else Prog_Warning(E_NLABELS);		/* otherwise complain */
		Save = Position;			/* Move the last "safe" position up now */
	}

	if ((Got==0) && Line_Delim(Line[Position])) {	/* If the line had nothing left on it, */
		Print_Line(P_NONE); return(FALSE); }		/* print it, and we're through with this line */
	Position = Save;				/* Otherwise, move Position back to it's last safe value */
	if (Which == 2) {				/* If this is a d.a. statement, */
		Equals(); return(FALSE); }		/* Process it */

	return(TRUE);					/* and continue processing on this line */
}
/* Sym_Fix -	Assigns index numbers
		to the symbols.  Also performs relocation of
		the symbols assuming data segment follows text
		and bss follows the data.  If global flag,
		make all undefined symbols defined to be externals.
*/

Sym_Fix()
{
	register struct sym_bkt **sbp1, *sbp2;
	int i = 0;
	extern char O_global;
	extern struct sym_bkt *Dot_bkt;

	for (sbp1 = sym_hash_tab; sbp1 < &sym_hash_tab[HASH_MAX]; sbp1++)
		if (sbp2 = *sbp1) for(; sbp2; sbp2 = sbp2->next_s)
		{
			if (O_global && (sbp2->attr_s & (S_DEC|S_DEF)) == 0)
			{
				sbp2->attr_s |= S_EXT | S_DEC;
				sbp2->csect_s = 0;
			}
			sbp2->value_s += sdi_inc(sbp2->csect_s, sbp2->value_s);
			if (sbp2->csect_s == Data_csect)
				sbp2->value_s += tsize;
			else if (sbp2->csect_s == Bss_csect)
				sbp2->value_s += tsize + dsize;
			if (sbp2 == Dot_bkt
			 || sbp2->attr_s & (S_REG|S_MACRO|S_LOCAL|S_PERM))
				sbp2->id_s = -1;
			else
				sbp2->id_s = i++;
		}
}


/* Sym_Write -	Write out the symbols to the specified
		file in b.out format, while computing size
		of the symbol segment in output file.
 */

long Sym_Write(file)
FILE *file;
{
	long size = 0;
	register struct sym_bkt  **sbp1, *sbp2;
	register char *sp;
#ifndef Stanford
	int slength;
#endif Stanford
	struct sym s;

	for (sbp1 = sym_hash_tab; sbp1 < &sym_hash_tab[HASH_MAX]; sbp1++)
		if (sbp2 = *sbp1) for (; sbp2; sbp2 = sbp2->next_s)
		{
			if (sbp2->id_s != -1) {
				if ((sbp2->attr_s&S_DEF)== 0)s.stype = UNDEF;
				else if (sbp2->csect_s == Text_csect) s.stype = TEXT;
				else if (sbp2->csect_s == Data_csect) s.stype = DATA;
				else if (sbp2->csect_s == Bss_csect) s.stype = BSS;
				else s.stype = ABS;
				if (sbp2->attr_s & S_EXT) s.stype |= EXTERN;
				s.svalue = sbp2->value_s;
				sp = sbp2->name_s;
#ifndef Stanford
				fwrite(&s, sizeof s, 1, file);
				slength = 0;
				do	/* write out asciz string and compute length */
				{
					putc(*sp, file);
					slength++;
				} while(*sp++);
				size =+ sizeof(s) + slength;
#else Stanford
				s.slength = strlen(sp);
				fwrite(&s, sizeof s, 1, file);
				fprintf(file,"%s",sp);
				putc('\0',file);
				size += sizeof s + s.slength + 1;
#endif Stanford
			}
		}
	return(size);
}

/*
 * Perm	Flags all currently defined symbols as permanent (and therefore
 *	ineligible for redefinition.  Also prevents them from being output
 *	in the object file).
 */
Perm()
{
	register struct sym_bkt **sbp1, *sbp2;
	for (sbp1 = sym_hash_tab; sbp1 < &sym_hash_tab[HASH_MAX]; sbp1++)
		for (sbp2 = *sbp1; sbp2; sbp2 = sbp2->next_s)
			sbp2->attr_s |= S_PERM;
}



/* LINTLIBRARY */
/*
 * setsegmap.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_setsegmap(cxt,segno,entry)	-- 
 *	sets segment map #segno in context #cxt to entry
 */

#include <sunemt.h>

int emt_setsegmap(cxt,segno,entry)
int cxt;
int segno;
int entry;
{
	return(
	    emt_call(EMT_SETSEGMAP,cxt,segno,entry)
	);
}

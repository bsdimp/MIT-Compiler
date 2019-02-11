/* LINTLIBRARY */
/*
 * getsegmap.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_getsegmap(cxt,segno)	-- 
 *	returns segment map entry #segno in context #cxt
 */

#include <sunemt.h>

int emt_getsegmap(cxt,segno)
{
	return(
	    emt_call(EMT_GETSEGMAP,cxt,segno)
	);
}

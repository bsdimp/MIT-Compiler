/* LINTLIBRARY */
/*
 * setcontext.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_setcontext(cxt)	-- sets context register to cxt
 */

#include <sunemt.h>

int emt_setcontext(cxt)
int cxt;
{
	return(
	    emt_call(EMT_SETCONTEXT,cxt)
	);
}

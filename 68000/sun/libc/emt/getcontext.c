/* LINTLIBRARY */
/*
 * getcontext.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_getcontext()	-- returns current context register contents
 */

#include <sunemt.h>

int emt_getcontext()
{
	return(
	    emt_call(EMT_GETCONTEXT)
	);
}

/* LINTLIBRARY */
/*
 * getmemsize.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_getmemsize()	-- returns on-board memory size in bytes
 */

#include <sunemt.h>

int emt_getmemsize()
{
	return(
	    emt_call(EMT_GETMEMSIZE)
	);
}

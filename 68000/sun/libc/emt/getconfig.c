/* LINTLIBRARY */
/*
 * getconfig.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_getconfig()	-- returns processor board configuration
 */

#include <sunemt.h>

int emt_getconfig()
{
	return(
	    emt_call(EMT_GETCONFIG)
	);
}

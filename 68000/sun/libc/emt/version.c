/* LINTLIBRARY */
/*
 * version.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_version()	-- returns monitor version number
 */

#include <sunemt.h>

int emt_version()
{
	return(
	    emt_call(EMT_VERSION)
	);
}

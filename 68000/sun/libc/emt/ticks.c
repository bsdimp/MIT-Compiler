/* LINTLIBRARY */
/*
 * ticks.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * int emt_ticks()	-- returns milliseconds since monitor booted
 */

#include <sunemt.h>

int emt_ticks()
{
	return(
	    emt_call(EMT_TICKS)
	);
}

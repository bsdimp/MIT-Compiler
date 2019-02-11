/* LINTLIBRARY */
/*
 * fbmode.c
 *
 * Sun MC68000 ROM monitor Emulator Trap package
 *
 * fbmode(mode) -- sets/queries monitor's frame buffer mode:
 *
 * INPUT:	flag = 1 or -1 => set FB mode to flag (unless FBmode == 0)
 *		flag = <other>	=> no side effects
 * OUTPUT:	1 = using FB
 *		0 = no fb present
 *		-1 = fb present but not in use
 *		
 */

#include <sunemt.h>

fbmode(mode)
int mode;
{
	return(
	    emt_call(EMT_FBMODE,mode)
	);
}

#include "sh.h"

dorlite(vp)
char **vp;
{

    register char	*cp;
    register		type;
    unsigned register	no;
    unsigned		base, addr, gettv();
    char		*ttyp = (char *) 0;
    char		*ttyname();

    vp++;
    cp = *vp++;
    for (;;) {

	if (cp == 0) {
	    type = 'b';
	    no = 41;
	    break;
	}
	if (*cp != 't' && *cp != 'b' && *cp != 'l' && *cp != 'r') {
	    type = 'b';
	    no = atoi(cp);
	    if (no < 1 || 80 < no) bferr("rite number out of range");
	    break;
	}
	type = *cp;
	cp = *vp++;
	if (cp == 0) {
	    switch (type) {
	    case 'b':
		no = 41;
		break;
	    case 't':
		no = 41;
		break;
	    case 'l':
		no = 0;
		break;
	    case 'r':
		no = 0;
		break;
	    }
	    break;
	}
	no = atoi(cp);
	ttyp = *vp;

	if ((type == 't' || type == 'b') &&
	    (no < 1 || 80 < no)) bferr("rite number out of range");
	if ((type == 'l' || type == 'r') &&
	    (no < 0 || 41 < no)) bferr("rlite number out of range");
	break;
    }

    base = gettv( (ttyp != 0 ? ttyp : ttyname(SHDIAG)));
    if (base == -1) return;
    switch (type) {
    case 't':
	addr = (6*no - 1)*84 + 82;
	break;
    case 'b':
	addr = (6*no - 1)*84;
	break;
    case 'l':
	addr = no*2;
	break;
    case 'r':
	addr = (84 * 486) + no*2;
	break;
    }

    base += addr/2048;
    if (base < 03000 || base > 03774) bferr("base address out of range");
    phys(-1, addr%2048, base);
}

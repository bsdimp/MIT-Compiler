#include	<stdio.h>

#undef putchar

_flsbuf(c, iop)
register FILE *iop;
{
	register char *base;
	register char *tptr;
	register n, rn;
	register int ii;
	char c1;
	extern char _sobuf[];

	if ((iop->_flag&_IOWRT)==0)
		return(EOF);
tryagain:
	if (iop->_flag&_IONBF) {
		c1 = c;
		rn = 1;
		n = rn;
		putchar(c1);
		iop->_cnt = 0;
	} else {
		if ((base=iop->_base)==NULL) {
			if (iop==stdout) {
				iop->_flag |= _IONBF;
				goto tryagain;
			}
			iop->_flag |= _IONBF;
			goto tryagain;
		} else if ((rn = n = iop->_ptr - base) > 0) {
			iop->_ptr = base;
			for (ii = 0, tptr = base; ii < n; ii++)
			    putchar(*tptr++);
		}
		iop->_cnt = BUFSIZ-1;
		*base++ = c;
		iop->_ptr = base;
	}
	if (rn != n) {
		iop->_flag |= _IOERR;
		return(EOF);
	}
	return(c);
}

fflush(iop)
register struct _iobuf *iop;
{
	register char *base;
	register n;

	if ((iop->_flag&(_IONBF|_IOWRT))==_IOWRT
	 && (base=iop->_base)!=NULL && (n=iop->_ptr-base)>0) {
		iop->_ptr = base;
		iop->_cnt = BUFSIZ;
		while (n--) putchar(base++);
	}
	return(0);
}

/*
 * Flush buffers on exit
 */

_cleanup()
{
	register struct _iobuf *iop;
	extern struct _iobuf *_lastbuf;

	for (iop = _iob; iop < _lastbuf; iop++)
		fclose(iop);
}

fclose(iop)
register struct _iobuf *iop;
{
	register r;

	r = EOF;
	if (iop->_flag&(_IOREAD|_IOWRT) && (iop->_flag&_IOSTRG)==0) {
		r = fflush(iop);
		if (iop->_flag&(_IOMYBUF|_IONBF))
			iop->_base = NULL;
	}
	iop->_flag &= ~(_IOREAD|_IOWRT|_IONBF|_IOMYBUF|_IOERR|_IOEOF|_IOSTRG);
	iop->_cnt = 0;
	return(r);
}

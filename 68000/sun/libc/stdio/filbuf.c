#include	<stdio.h>

#undef getchar
#undef putchar

_filbuf(iop)
register FILE *iop;
{
	static char smallbuf[_NFILE];

	if ((iop->_flag&_IOREAD) == 0)
		return(EOF);
	if (iop->_flag&_IOSTRG)
		return(EOF);
tryagain:
	if (iop->_base==NULL) {
		if (iop->_flag&_IONBF) {
			iop->_base = &smallbuf[fileno(iop)];
			goto tryagain;
		}
		iop->_flag |= _IONBF;
		goto tryagain;
	}
	iop->_ptr = iop->_base;
	iop->_cnt = x_read(iop->_ptr, iop->_flag&_IONBF?1:BUFSIZ);
	if (--iop->_cnt < 0) {
		if (iop->_cnt == -1)
			iop->_flag |= _IOEOF;
		else
			iop->_flag |= _IOERR;
		iop->_cnt = 0;
		return(-1);
	}
	return(*iop->_ptr++&0377);
}

x_read(adr,max)
register char *adr;
register int max;
{
	register char *cptr = adr;
	register char c;
	register int count = 0;
	register int NonSpaceSeen = 0;
	
	while (count++ < max) {
		c = getchar()&0x7F;	/* strip parity, sucko concepts */
		if (c == '\r') {	/* change \n to \r */
		    c = '\n';
		    putchar('\n');	/* echo a newline, too */
		}
		*cptr++ = c;

		if (c == '\n') break;

		switch (c) {

		case '\04':	/* CTRL/D == EOF */
			return(-1);

		case '\b':	/* backspace */
			putchar(' ');	/* cancel effect of backspace */
					/* then drop into <delete> */
		case 0x7F:	/* <delete> */
			cptr--;		/* remove <delete> */
			if (--count == 0) {	/* end of the line */
			    break;
			}
			count--;	/* don't count erased char */
			if (*--cptr == '\t') {  /* tabs are a pain */
			    cptr = 0;	/* null-term it here */
			    printf("\n%s",adr);	/* reprint line */
			}
			else
			    printf("\b \b");
			break;

		case '\025':	/* CTRL/U == kill line */
				/* but only for this call of x_read()! */
			cptr = adr;
			count = 0;
			printf(" XXX\n");
			break;

		case '\022':	/* CTRL/R == reprint line */
			*cptr-- = 0;	/* null-term it here */
			count--;	/* ignore the CTRL/R */
			printf("\n%s",adr);	/* reprint what WE have */
			break;
		
		case '\027':	/* CTRL/W == erase word */
			cptr -= 2;   /* ignore CTRL/W, point to last char */
			count--;
			NonSpaceSeen = 0;
			
			while (count) {
			    if (NonSpaceSeen) {
			    	if ((*cptr == ' ') || (*cptr == '\t'))
				    break;
			    }
			    if (*cptr == '\t') { /* tabs are a pain */
				/* first, eat up white space */
				while ((*cptr == '\t') || (*cptr == ' ')) {
				    *cptr-- = 0;   /* null-term it here */
				    if (count-- == 0) break;
				}
				/* then, reprint line */
				printf("\n%s",adr);
				continue;
			    }
			    if (*cptr != ' ') NonSpaceSeen++;
			    cptr--;
			    count--;
			    printf("\b \b");
			}
			cptr++;	/* now point to free slot */
			break;
		
		default:
			break;
			
		}
	}
	
	return(count);
}

		

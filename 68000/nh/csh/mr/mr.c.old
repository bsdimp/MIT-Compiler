#ifdef DBG
#include <stdio.h>
#endif
#include <sgtty.h>

/*
 * Meta Read
 * 		should be called from programs such as shells instead
 * of read.  provides for filename completion, filename choices,
 * forward/backword word/char, and retype.
 * needs CBREAK (could also set erase and kill to 0377 and have tty driver
 * break on all chars les than 040 as old one does).  set mode using
 * sp = mr_in(tty_fd), clear mode using mr_out(tty_fd, sp).
 * not too hard to hack into csh, and bourne shell. should be even easier
 * if the program is designed from scratch for MR.  ptp is pointer
 * to prompt to be typed before retype.
 */


mr_in(fd)
{
struct sgttyb parms;

    ioctl(fd, TIOCGETP, &parms);
    parms.sg_flags |= CBREAK;
/*
    parms.sg_flags &= ~ECHO;
*/
    ioctl(fd, TIOCSETN, &parms);
    return(parms.sg_flags);
}


mr_out(fd, wd)
int	*wd;
{
struct sgttyb parms;

    wd = wd;
    ioctl(fd, TIOCGETP, &parms);
    parms.sg_flags &= ~CBREAK;
/*
    parms.sg_flags |= ECHO;
*/
    ioctl(fd, TIOCSETN, &parms);
    return(parms.sg_flags);
}

#define MR_STOPPERS	" '\"\t`;&<>()|^/%="
#define MR_FSTOPPERS	" '\"\t`;&<>()|^%="	/* no slash	*/
#define CTL(x)		('x' - 0100)
#define ESC		033
#define NL		012

#define MR_ERASE	CTL(H)
#define MR_KILL		CTL(U)
#define MR_EOF		CTL(D)
#define MR_RETYPE	CTL(R)
#define MR_BACK_WORD	CTL(W)
#define MR_FORW_WORD	CTL(F)
#define MR_FORW_CHAR	CTL(L)
#define MR_FILE_POSS	CTL(A)
#define MR_FILE_COMP	ESC

/*
#define MR_ECHO(c)		outc(fd_err, c);
*/
#define MR_ECHO(c)
#define MR_MIN(a, b)	(a < b ? a : b)

#define MR_SIZ		(512 + 20)


/*@*/

mr(fd_in, fd_out, fd_err, bp, acc, ptp, sht, f)
char		*bp, *ptp;
short		sht;
{
register char	*ap, *hp, *tp;
int	nfiles;
int	freshf = 1;
int	cc = acc;
char	c;
static char	inbuf[MR_SIZ];
static char	tobuf[MR_SIZ];
static char	svbuf[MR_SIZ];
static int	len;
static char	*ip = inbuf;

    tp = hp = tobuf;
    while (1) {
	if (len <= 0) {
	    if ( (len = read(fd_in, inbuf, MR_MIN(cc, 512))) <= 0) {
		if (len < 0) return(-1);
		if (tp = tobuf) {
		    inbuf[0] = MR_EOF;
		    len = 1;
		} else {
		    strncpy(svbuf, tobuf, tp - tobuf);
		    svbuf[tp - tobuf] = 0;
		    strncpy(bp, tobuf, tp - tobuf);
		    return(tp - tobuf);
		}
	    }
	    ip = inbuf;
	}
	while (len) {
	    if (acc == (tp - tobuf)) {
		strncpy(svbuf, tobuf, acc);
		if (acc < sizeof svbuf) svbuf[acc] = 0;
		strncpy(bp, tobuf, acc);
		return(acc);
		break;
	    }
	    --len;
	    --cc;
	    c = *ip++;
	    switch(c) {
	    case MR_EOF:
		if (tp == tobuf) {
		    return(0);
		}
		if (tp > tobuf) {
		    strncpy(bp, tobuf, tp - tobuf);
		    strncpy(svbuf, tobuf, tp - tobuf);
		    if (tp - tobuf < sizeof(tobuf)) svbuf[tp - tobuf] = 0;
		    return(tp - tobuf);
		}
		break;
	    case MR_ERASE:
		if (tp > tobuf) {
		    tp--;
/*
		    backup(fd_err, 1);
*/
		    out(fd_err, " \b");
		}
		break;
	    case MR_KILL:
		if (tp > tobuf) {
		    backup(fd_err, tp - tobuf);
		}
		tp = tobuf;
		break;
	    case MR_FILE_POSS:
		out(fd_err, "\n");
	    case MR_FILE_COMP:
		*tp = 0;
		for (ap = tp; ap >= tobuf; --ap)
		    if (any(ap, MR_FSTOPPERS)) break;
		nfiles = recognize(++ap, c, fd_err);
		if (c == MR_FILE_POSS) {
		    out(fd_err, ptp);
		    out(fd_err, tobuf);
		    break;
		}
		if (nfiles > 0) {
		    ap = tp;
		    while (*tp++);
		    tp--;
		    outn(fd_err, ap, tp - ap);
		    hp = tp;
		}
		if (nfiles != 1)
		    out(fd_err, "\007");
		break;
	    case MR_BACK_WORD:
		ap = tp;
		if (ap > tobuf && *(ap-1) == '/' &&
		    ap-1 > tobuf && any(ap-2, MR_STOPPERS)) {
			backup(fd_err, 1);
			tp--;
			break;
		}
		while (ap > tobuf && any(ap-1, MR_STOPPERS)) {
		    backup(fd_err, 1);
		    ap--;
		}
		while (ap > tobuf && !any(ap-1, MR_STOPPERS)) {
		    backup(fd_err, 1);
		    ap--;
		}
		tp = ap;
		break;
	    case MR_FORW_WORD:
		ap = tp;
		while (ap <= hp) {
		    if (!any(ap, MR_STOPPERS)) break;
		    outn(fd_err, ap++, 1);
		}
		while (ap <= hp) {
		    if (any(ap, MR_STOPPERS)) break;
		    outn(fd_err, ap++, 1);
		}
		tp = ap;
		break;
	    case MR_FORW_CHAR:
		if (tp <= hp) {
		    out(fd_err, "\b");		/* take out if echo	*/
		    outn(fd_err, tp++, 1);
		}
		break;
	    case MR_RETYPE:
		if (tp == tobuf) {
		    if (hp > tp) {
			outn(fd_err, tobuf, hp - tobuf + 1);
			tp = hp + 1;
			break;
		    }
		    strcpy(tobuf, svbuf);
		    if (ap = rindex(tobuf, '\n')) *ap = 0;
		    tp = ap;
		    hp = ap - 1;
		    out(fd_err, tobuf);
		    break;
		}
		*tp = 0;
		out(fd_err, "\n");
		out(fd_err, ptp);
		outn(fd_err, tobuf, tp - tobuf);
		break;
	    case NL:
		if (tp >= &tobuf[sizeof(tobuf) - 2]) {
		    out(fd_err, "mr: line too long.\n");
		}
		MR_ECHO(c);
		*tp++ = c;
		*tp = 0;
		strncpy(svbuf, tobuf, tp - tobuf);
		if (tp - tobuf < sizeof(svbuf)) svbuf[tp - tobuf] = 0;
		strncpy(bp, tobuf, tp - tobuf);
		return(tp - tobuf);
		break;
	    default:
		if (tp >= &tobuf[sizeof(tobuf) - 1]) {
		    out(fd_err, "mr: line too long.\n");
		}
		MR_ECHO(c);
		if (tp > hp) hp = tp;
		*tp++ = c;
		break;
	    }
	}
	if (acc == (tp - tobuf)) {
	    strncpy(svbuf, tobuf, acc);
	    if (acc < sizeof svbuf) svbuf[acc] = 0;
	    strncpy(bp, tobuf, acc);
	    return(acc);
	    break;
	}
    }
    out(fd_err, "mr: fall out\n");
}


static
recognize (file, typ, fd_out)
char   *file;
{
register    i;
register char  *p1, *p2;
int     file_cnt, dir_fd, len;
char    block[512], dir[64], filnam[16], fullfilnam[16], entry[16];
struct dir_ent
{
    short	ino;
    char	fn[14];
};

    df_parse (file, dir, sizeof dir, filnam);
    if ( (dir_fd = open (dir, 0)) < 0)
	return (0);
    file_cnt = 0;
    while (1) {
	len = read (dir_fd, block, 512);
	if (len <= 0)
	    break;
	for (i = 0; i < len; i =+ 16) {
	    if ( ((struct dir_ent *)(&block[i]))->ino != 0) {
		strncpy (entry, ((struct dir_ent *)(&block[i]))->fn, 14);
		entry[14] = 0;
		if (match (filnam, entry)) {
		    if (typ == MR_FILE_POSS) {
			out(fd_out, entry);
			out(fd_out, "\n");
		    } else {
			if (++file_cnt == 1) {
			    strncpy (fullfilnam, entry, 14);
			    fullfilnam[14] = 0;
			}
			else {
			    p1 = fullfilnam;
			    p2 = entry;
			    while (*p1++ == *p2++) ;
			    *--p1 = 0;
			    if (strcmp(fullfilnam, filnam) == 0)
				goto fini;
			}
		    }
		}
	    }
	}
    }
fini: 
    close(dir_fd);
    if (typ == MR_FILE_COMP && file_cnt > 0) {
	file[0] = 0;
	if (strcmp(".", dir) != 0)
	    strncpy(file, dir, 64);
	strcat(file, fullfilnam);
	return (file_cnt);
    }
    return (0);
}


/* return true if chk matches initial chars in template */

static
match (chk, template)
char   *chk, *template;
{
register char  *c, *t;

    c = chk;
    t = template;
    do
	if (*c == 0)
	    return (1);
    while (*c++ == *t++) ;
    return (0);
}


/*
 * parse full path into 2 parts: directory and file names
 * filename must be at least 16 chars.
 * max dirlen is parm.
 */

static
df_parse (file, dir, max, filnam)
char   *file,
       *dir,
       *filnam;
{
    register char  *p;
    p = file;
    while (*p++);
    while (p > file)
	if (*--p == '/')
	{
	    strncpy(dir, file, MR_MIN(p - file + 1, max));
	    dir[MR_MIN(p - file + 1, max)] = 0;
	    strncpy (filnam, ++p, 14);
		    filnam[14] = 0;
	    return;
	}
    strcpy (dir, ".");
    strncpy (filnam, file, 14);
    filnam[14] = 0;
}


static
void
outc(fd, c)
char c;
{

    write(fd, &c, 1);
}


static
void
out(fd, bp)
char	*bp;
{
    write(fd, bp, strlen(bp));
}


static
void
outn(fd, bp, cc)
char	*bp;
{
    write(fd, bp, cc);
}


void
backup(fd, n)
{

    while(n--) {
	out(fd, "\b \b");
    }
}


static
char *
any (ap, bp)
register char	*ap;
register char	*bp;
{

    while (*bp)
	if (*bp++ == *ap)
	    return (bp);
    return (0);
}


#ifdef DBG
#include <signal.h>
#include <stdio.h>
int rubout();

main(argc, argv)
int 		argc;
char 		**argv;
{

char		buf[MR_SIZ];
int		len;
int		fd;
int		save_chars;

signal(SIGINT, rubout);
save_chars = mr_in(2);
if (argc > 1) {
    if ( (fd = open(argv[1], 0)) < 0) {
	fprintf(stderr, "couldn't open %s\n", argv[1]);
	mr_out(2, &save_chars);
	exit(1);
    }
    while ( (len = mr(fd, 1, 2, buf, MR_SIZ, "", &save_chars, 0))) {
	write(1, buf, len);
    }
    mr_out(2, &save_chars);
    exit(0);
}
while (1) {
    write(2, "! ", 2);
    len = mr(0, 1, 2, buf, MR_SIZ, "! ", &save_chars, 0);
    if (len < 0) {
	write(2, "\n", 1);
	continue;
    }
    buf[len] = 0;
    printf("len = %d. str = |%s|\n", len, buf);
//    if (len == 0) break;
    if (strncmp("exit", buf, 4) == 0) {
	mr_out(2, &save_chars);
	exit(0);
    }
    if (strncmp("test", buf, 4) == 0) {
	fprintf(stderr, "test\n");
    }
    mr_out(2, &save_chars);
    mr_in(2);
}

mr_out(2, &save_chars);
}

rubout(x)
{

    signal(SIGINT, rubout);
}
#endif

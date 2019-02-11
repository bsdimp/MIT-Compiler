static	char sccsid[] = "@(#)ranlib.c 4.3 4/26/81";
/*
 * ranlib - create table of contents for archive; string table version
 */
#include <sys/types.h>
#include <ar.h>
#include <ranlib.h>
#include <a.out.h>
#include <stdio.h>
#include <globaldefs.h>

#define TABSZ		5000
#define	STRTABSZ	75000

struct	ar_hdr	archdr;
long	arsize; /* arsize is the size of the last file element (minus the 
		   header) read by nextel
		*/
struct	exec	filhdr;
FILE	*fi, *fo;
long	off, oldoff;			/* offset counters in the archive file */
long	atol(), ftell();
struct	ranlib tab[TABSZ];
short	tnum;
short	new;
char	tstrtab[STRTABSZ];
int	tssiz;				/* the tstrtab table counter */
char	*strtab;
int	ssiz;
char	tempnm[] = DIRNAME;
char	firstname[17];
char	symbuf[SYMLENGTH+1];	/* temp buffer for symbol name */

main(argc, argv)
char **argv;
{
	char cmdbuf[BUFSIZ];
	short magbuf;				/* MFM */

	--argc;
	while(argc--) {
		fi = fopen(*++argv,"r");
		if (fi == NULL) {
			fprintf(stderr, "ranlib: cannot open %s\n", *argv);
			continue;
		}
		off = SARMAG;
		fread((char *)&magbuf, 1, sizeof(filhdr.a_magic), fi);
		if (magbuf != ARMAG) {
			fprintf(stderr, "%s is not an archive file. \n", *argv);
			continue;
		}
		new = tnum = 0;
		if (nextel(fi) == 0) {
			fclose(fi);
			continue;
		}
		do {
			long o;
			register n;
			struct nlist_ sym;

			fread((char *)&filhdr, 1, sizeof(struct exec), fi);
			if (N_BADMAG(filhdr))
				continue;
			if (filhdr.a_lesyms == 0) {
				fprintf(stderr, "ranlib: warning: %s(%s): no symbol table\n", *argv, archdr.ar_name);
				continue;
			}
			o = LESYMPOS - sizeof (struct exec);
			if (ftell(fi)+o+sizeof(ssiz) >= off) {
				fprintf(stderr, "ranlib: %s(%s): old format .o file\n", *argv, archdr.ar_name);
				exit(1);
			}
			fseek(fi, o, 1);
			/* we should now be at the beginning of the lest */
			n = filhdr.a_lesyms;
			while (n > 0) {
				/* read the nlist_ structure first. Then read
				   the following name into a buffer. 
				*/
				fread((char *)&sym, sizeof(sym), 1, fi);
				fread (symbuf, sym.n_length, 1, fi);
				n -= sizeof(sym) + sym.n_length;
				if ((sym.n_type & EXTERN)==0)
					continue;
				switch (sym.n_type&LO5BITS) {

				case UNDEF : 
					if (sym.n_value) stash(&sym);
					/* Undefined syms with a non-zero 
					   value indicate a .comm symbol.
					   These will be consolidated later. 
					*/
					continue;

				default :
					stash(&sym);
					continue;
				}
			}
		} while(nextel(fi));
		new = fixsize();
		fclose(fi);
		fo = fopen(tempnm, "w");
		if(fo == NULL) {
			fprintf(stderr, "can't create temporary\n");
			exit(1);
		}
		/* first write out the number of ranlib structures */
		fwrite(&tnum,  sizeof (tnum), 1, fo);
		/* write out the size of the ascii table */
		fwrite(&tssiz, 1, sizeof (tssiz), fo);
		/* write out the ascii table */
		fwrite(tstrtab, tssiz, 1, fo);
		/* now write out the ranlib structures themselves */
		fwrite((char *)tab, sizeof(struct ranlib), tnum, fo);
		fclose(fo);
		if(new)
			sprintf(cmdbuf, "ar rlb %s %s %s\n", firstname, *argv, tempnm);
		else
			sprintf(cmdbuf, "ar rl %s %s\n", *argv, tempnm);
		if(system(cmdbuf))
			fprintf(stderr, "ranlib: ``%s'' failed\n", cmdbuf);
		else
			fixdate(*argv);
		unlink(tempnm);
	}
	exit(0);
}

/* nextel reads the archive header and fills certain globals */

nextel(af)
FILE *af;
{
	register char *cp;

	oldoff = off;
	fseek(af, off, 0);
	if (fread((char *)&archdr, 1, sizeof(struct ar_hdr), af) != sizeof(struct ar_hdr))
		return(0);
	for (cp=archdr.ar_name; cp < & archdr.ar_name[sizeof(archdr.ar_name)]; cp++)
		if (*cp == ' ')
			*cp = '\0';
	arsize = archdr.ar_size;
	if (arsize & 1)
		arsize++;
	off = ftell(af) + arsize;
	return(1);
}

stash(s)
	struct nlist_ *s;
{
	register unsigned char i = 0;
	if(tnum >= TABSZ) {
		fprintf(stderr, "ranlib: symbol table overflow\n");
		exit(1);
	}
	symbuf[s->n_length] = 0;		/* make symbol asciz */
	tab[tnum].ran_un.ran_strx = tssiz;
	tab[tnum].ran_off = oldoff;
	if ((tssiz+s->n_length+1) > STRTABSZ) {
		fprintf(stderr, "ranlib: string table overflow\n");
		exit(1);
	}
	else
		while (tstrtab[tssiz++] = symbuf[i++]);
	tnum++;
}





/* fixsize -	Now that the asciz table and the ranlib structure table have
		been made, their sizes are known. It is now possible to go
		back thru the ranlib structure table and adjust the ran_off
		fields so that they will show the true offset of the library
		member files relative to the beginning of the archive.
*/


fixsize()
{
	register int i;
	register off_t offdelta;	/* the correction factor taking into
					   account the sizes of the __.SYMDEF
					   structures now that they're known */

	if (tssiz&1)
		tssiz++;
	offdelta = sizeof(archdr) + sizeof (tnum) + tnum * sizeof(struct ranlib)
			+ sizeof (tssiz) + tssiz;
	off = SARMAG;

	/* look at the 1st file in the archive. If it's a directory from a prior
	   ranlib run, it will have to be replaced anyway so don't count it.
	*/
	nextel(fi);
	if((new = strncmp(archdr.ar_name, tempnm, sizeof (archdr.ar_name))) == 0) {
		/* new = 0; */
		offdelta -= sizeof(archdr) + arsize;
	} else {
		/* new = 1; */
		strncpy(firstname, archdr.ar_name, sizeof(archdr.ar_name));
	}
	for(i=0; i<tnum; i++)
		tab[i].ran_off += offdelta;
	return(new);
}

/* patch time */
fixdate(s)
	char *s;
{
	long time();
	int fd;

	fd = open(s, 1);
	if(fd < 0) {
		fprintf(stderr, "ranlib: can't reopen %s\n", s);
		return;
	}
	lseek(fd, (long)sizeof(filhdr.a_magic) + ((char *)&archdr.ar_date-(char *)&archdr), 0);
	write(fd, (time(NULL)+5), sizeof(archdr.ar_date));
	close(fd);
}


/*
 * Structure of the __.SYMDEF table of contents for an archive.
 *
 * ______________________________________________________________________
 * |           								|
 * |	Number of ranlib structures in __.SYMDEF (1 word)(rantnum in ld)|
 * |____________________________________________________________________|
 * |									|
 * |	Sizeof string table (# bytes) - 1 long (rasciisize in ld)	|
 * |____________________________________________________________________|
 * |									|
 * |	String table (asciz strings)					|
 * |____________________________________________________________________|
 * |									|
 * |	ranlib structure array (1 per defined external sym)		|
 * |____________________________________________________________________|
 */

#define DIRNAME "__.SYMDEF"

typedef long off_t;

struct	ranlib {
	union {
		off_t	ran_strx;	/* string table index of this sym */
		char	*ran_name;
	} ran_un;
	off_t	ran_off;		/* library member is at this offset */
};

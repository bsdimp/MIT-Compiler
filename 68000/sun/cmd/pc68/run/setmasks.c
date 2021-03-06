/* Tables used for Pascal set operations */
/* Also notzero() which prints an error message */

long _btabl[32] = { /* _btabl[i] = 2**(31 - i) */
		0x80000000, 0x40000000, 0x20000000, 0x10000000,
		 0x8000000,  0x4000000,  0x2000000,  0x1000000,
		  0x800000,   0x400000,   0x200000,   0x100000,
		   0x80000,    0x40000,    0x20000,    0x10000,
		    0x8000,     0x4000,     0x2000,     0x1000,
		     0x800,      0x400,      0x200,      0x100,
		      0x80,       0x40,       0x20,       0x10,
		       0x8,        0x4,        0x2,        0x1};

long _rmask[32] = {
		0xFFFFFFFF, 0x7FFFFFFF, 0x3FFFFFFF, 0x1FFFFFFF,
		 0xFFFFFFF,  0x7FFFFFF,  0x3FFFFFF,  0x1FFFFFF,
		  0xFFFFFF,   0x7FFFFF,   0x3FFFFF,   0x1FFFFF,
		   0xFFFFF,    0x7FFFF,    0x3FFFF,    0x1FFFF,
		    0xFFFF,     0x7FFF,     0x3FFF,     0x1FFF,
		     0xFFF,      0x7FF,      0x3FF,      0x1FF,
		      0xFF,       0x7F,       0x3F,       0x1F,
		       0xF,        0x7,        0x3,        0x1};

long _lmask[32] = {
		0x80000000, 0xC0000000, 0xE0000000, 0xF0000000,
		0xF8000000, 0xFC000000, 0xFE000000, 0xFF000000,
		0xFF800000, 0xFFC00000, 0xFFE00000, 0xFFF00000,
		0xFFF80000, 0xFFFC0000, 0xFFFE0000, 0xFFFF0000,
		0xFFFF8000, 0xFFFFC000, 0xFFFFE000, 0xFFFFF000,
		0xFFFFF800, 0xFFFFFC00, 0xFFFFFE00, 0xFFFFFF00,
		0xFFFFFF80, 0xFFFFFFC0, 0xFFFFFFE0, 0xFFFFFFF0,
		0xFFFFFFF8, 0xFFFFFFFC, 0xFFFFFFFE, 0xFFFFFFFF};

notzero() {
	printf("Error -- set not all zeroes");
	_xit (-1);
}

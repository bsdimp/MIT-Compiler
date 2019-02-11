			Format of the file ins68

			       V.R. Pratt
			       Jan., 1981

The file ins68 contains a compacted list of all the instructions of the 68000,
together with the assembler form of each instruction.  It also contains the
format of the effective address field.

Instruction List Format

The format of the instruction list is as follows.  Each entry is terminated 
with \n.  An entry consists of a bit form and an assembler form; the two forms
are separated by at least one tab.  

The bit form is a list of words separated by commas.  Each word is either one 
character or 16 characters.  A one character word such as n is considered 
merely an abbreviation for the 16-character word nnnnnnnnnnnnnnnn.  

Here is a simple entry.

0100111001110110	trapv

This says that the instruction with hex opcode 4E76 has the assembler form
trapv.  Not all instructions consist merely of 0's and 1's; consider

0100100001000ddd	swap d

This says that the instruction 4840 is swap d0, 4841 is swap d1, etc., up to 
4847.  The block of d's in the word defines a field.  The interpretation of
the field depends on the letter used for the field.  The following letters have
special interpretations.

d	data register
a	address register
e	effective address
s	size: 0 = w, 1 = l, 00 = b, 01 = w, 10 = l, 11 = * (illegal)
n	signed short integer, decimal in assembler form
b	like n, but bivalent: length agrees with most recent value of s
x	unsigned short integer, hex in assembler form
y	like x but bit-reversed in assembler form
m	m = 1 -> reverse arguments in assembler form
f	function defined locally (as in f(div,mul) meaning 0 = div, 1 = mul)
c	condition code (for branch, decrement-and-branch, and conditional set)
r	relative program point; an address to be printed symbolically if 
	possible, otherwise in hex if pc is known, otherwise in hex but
	relative to the pc

When two separate fields require the same letter, the two fields are
distinguished by case, e.g. d versus D.  The field E is treated specially; 
its register and mode fields are interchanged relative to e, for which a
handy informal mnemonic is E = RRRMMM, e = mmmrrr.  The bits within the
register and mode fields are not themselves reversed in either case.

Here are further examples.

00ffEEEEEEeeeeee	mov.f(,b,l,w) e,E

This is the move instruction.  Since the size field is nonstandard we define
it locally as 01 = b, 10 = l, 11 = w.  There are two effective addresses, e
and E, respectively source and destination.  The . is a delimiter that
is removed, thus 0010111000000011 becomes   movl d3,d7.

Here are the instructions to logically combine n with either the condition code
register (a byte operation) or the status register (a word operation).  

0000fff00F111100,n	f(or,and,*,*,*,eor,*,*) #n,F(ccr,sr)

For example 0000101000111100,0000000000100101 would be eor #37,ccr.  
(Remember that n is merely an abbreviation for nnnnnnnnnnnnnnnn.)  There are
two locally defined functions, hence f and F.  When * appears in the 
assembler form this denotes an illegal instruction.

It is permissible for a bit pattern to match more than one form.  For example
0100000011000000 matches both of the following two patterns; the intended 
match is always the earlier in such a case.

0100000011eeeeee	move sr,e
01000000sseeeeee	negx.s e

The one place where bit-reversal is used is in

01001m001seeeeee,y	movem.s y,e

This prints the bits of y to correspond to the register sequence
d0 d1 ... d7 a0 a1 ... a7.  All movem's print in this order, regardless of
the order actually used in saving and restoring registers.  It is almost
never needed to know the physical order of saving, only the set saved.
(Incidentally note the one-bit s; 0 = w, 1 = l.)

The following illustrates condition codes and relative program points.

0101cccc11001ddd,r	db.c d,r

Thus 0101011111001101,1111111111110010 would be   dbeq d5,.-14. assuming no
symbol was available for this address.

Here is an example of the signed integer n appearing as a field in the
move-quick instruction.

0111ddd0nnnnnnnn	moveq #n,d

Here is an example of the use of b (both word and long constant possible).

0000fff0sseeeeee,b	f(or,and,sub,add,,eor,cmp,).s #b,e

Both 0000000000000000,0000000000000000 and 0000000001000000,0000000000000000 
match this pattern; 0000000010000000,0000000000000000,0000000000000000 also
matches because s = 10 = l.

Effective Address Format

In addition to the instructions, the file ins68 gives the format of the
effective address, using the same conventions.  The following examples should
be self-explanatory.

000ddd			d
001aaa			a
101aaa,n		a@(n)
110aaa,00000dddnnnnnnnn	a@(n,d)	(note how the second word cannot be abbrev'd.)
110aaa,00001aaannnnnnnn	a@(n,a)	(note how d and a are dealt with in the ext'n)
11100s,b		b	(here s is used only to control the size of b)
111100,b		#b	(the size of b depends on s defined outside e)


Note the ambiguity resulting from both the instruction proper and the
effective address wanting arguments.  The rule is that arguments for the
instruction proper come first in the instruction being matched to a pattern.

Caveat

Any word list no initial segment of which matches a pattern in the instruction
list does not start out with a legal instruction.  The converse is not true;
some illegal instructions match some pattern.  Most of these have assembler
forms containing an asterisk, but in the present table there exist exceptions.
We would be grateful if someone would make the necessary additions to the
table to eliminate those exceptions; this is done by putting the exceptions
in the table ahead of the patterns they match and supplying them with an
assembler form of *.


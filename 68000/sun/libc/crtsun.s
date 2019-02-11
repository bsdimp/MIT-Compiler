| Initial run-time module for C programs on a stand-alone
| SUN.  Commented by Bill Nowicki March 1982
| Note that because of Vaughan's ddtinit hack, you must have
| a dummy routine called ddtinit for this to work.

	.data
	.text
	.globl	_start
	.globl	__end
_start:	jra	__st1
__end:	.long	_end+4
__st1:	jsr	ddtinit
	jsr	main
	trap	#14
	jra	__st1

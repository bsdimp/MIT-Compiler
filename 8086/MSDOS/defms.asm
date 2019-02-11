
;
; Definitions for MS-DOS
;

;
;  System functions for "interrupt 21"
;    (Note: functions followed by "*" are
;           not CP/M compatable
;

DOSF_TERM	EQU  0		; Program terminate
DOSF_CONIN	EQU  1		; Console input
DOSF_CONOUT	EQU  2		; Console output
DOSF_AUXIN	EQU  3		; Aux input
DOSF_AUXOUT	EQU  4		; Aux output
DOSF_PRINTOUT	EQU  5		; Printer output
DOSF_DRCIO	EQU  6		; Direct console I/O
DOSF_DRCI	EQU  7		; * Direct console input
DOSF_DRCINE	EQU  8		; * Console input(no echo)
DOSF_OUTSTR	EQU  9		; Output string
DOSF_INSTR	EQU 10		; Input string
DOSF_STCON	EQU 11		; Status of console
DOSF_CONINF	EQU 12		; * Flush keyboard buffer and input
DOSF_RSDISK	EQU 13		; Disk system reset
DOSF_SELDISK	EQU 14		; Select default disk
DOSF_OPFILE	EQU 15		; Open file
DOSF_CLFILE	EQU 16		; Close file
DOSF_SRHFI	EQU 17		; Search for first
DOSF_SRHNX	EQU 18		; Search for next
DOSF_DEFILE	EQU 19		; Delete file
DOSF_SEQREAD	EQU 20		; Sequential read
DOSF_SEQWRITE	EQU 21		; Sequential write
DOSF_CRFILE	EQU 22		; Create file
DOSF_REFILE	EQU 23		; Rename file
DOSF_24		EQU 24		; * not used
DOSF_GETDISK	EQU 25		; Get default disk
DOSF_SDIOA	EQU 26		; Set disk I/O address

;* The remaining functions are not CP/M compatable

DOSF_RANREAD	EQU 33		; Random read
DOSF_RANWRITE	EQU 34		; Random write
DOSF_GFSIZE	EQU 35		; Get file size
DOSF_SFPOS	EQU 36		; Set file position
DOSF_SIVEC	EQU 37		; Set interrupt vecter
DOSF_CESEG	EQU 38		; Create segment
DOSF_RBLREAD	EQU 39		; Random block read
DOSF_RBLWRITE	EQU 40		; Random block write
DOSF_PARSE	EQU 41		; Parse file name
DOSF_GDATE	EQU 42		; Get date
DOSF_SDATE	EQU 43		; Set date
DOSF_GTIME	EQU 44		; Get time
DOSF_STIME	EQU 45		; Set time
DOSF_CVERF	EQU 46		; Set/Reset verify flag

;*	DEFMS20 - Define Z-DOS 2.0 system calls
;
;	These calls are the added 2.0 function calls
;
;	10/13/82 - bcb
;

;	Extended functionality group

DOSF_GETDMA	EQU 47		; Get DMA address
DOSF_GETVER	EQU 48		; Get DOS version
DOSF_KEEPPRC	EQU 49		; Keep processes (int 27)
DOSF_SETCTLC	EQU 51		; Set ^C trapping
DOSF_INDOS	EQU 52		; Get dos critical flag
DOSF_INTVEC	EQU 53		; Set/get interrupt vector
DOSF_DRVFRE	EQU 54		; Drive free space
DOSF_CHROP	EQU 55		; Character operations
DOSF_INTERN	EQU 56		; International infor

;	XENIX calls

DOSF_MKDIR	EQU 57		; Make directory
DOSF_RMDIR	EQU 58		; Remove directory
DOSF_CHDIR	EQU 59		; Change directory

;	File group

DOSF_CREATH	EQU 60		; Create file
DOSF_OPENH	EQU 61		; Open file
 DOSFO_RED	 EQU 0		;  Open for read
 DOSFO_WRT	 EQU 1		;  Open for write
 DOSFO_RW	 EQU 2		;  Open for read/write
DOSF_CLOSEH	EQU 62		; Close file
DOSF_READH	EQU 63		; Read file
DOSF_WRITEH	EQU 64		; Write file
DOSF_UNLINK	EQU 65		; Unlink file
DOSF_LSEEK	EQU 66		; Logical seek file
 DOSFL_BEG	 EQU 0		;  Seek from begining
 DOSFL_CUR	 EQU 1		;  Seek from current
 DOSFL_END	 EQU 2		;  Seek from end
DOSF_CHMOD	EQU 67		; CHMOD of file
DOSF_IOCTL	EQU 68		; IOCTL value
 DOSFI_GDI	 EQU 0		;  Get device information
 DOSFI_SDI	 EQU 1		;  Set device information
 DOSFI_RED	 EQU 2		;  Read from device
 DOSFI_WRT	 EQU 3		;  Write to device
DOSF_XDUP	EQU 69		; DUP handle
DOSF_XDUP2	EQU 70		; DUP2 handle
DOSF_CWD	EQU 71		; Current directory

;	Memory allocation group

DOSF_ALLOC	EQU 72		; Allocate block
DOSF_DEALLOC	EQU 73		; Deallocate block
DOSF_SETBLK	EQU 74		; Set block to size

;	Process group

DOSF_EXEC	EQU 75		; Execute
 DOSX_GO	 EQU 0		;  EXEC program
 DOSX_LOAD	 EQU 2		;  Load only, no PHD, don't run
DOSF_EXIT	EQU 76		; Exit
DOSF_WAIT	EQU 77		; Wait
DOSF_FFIRST	EQU 78		; Find first

;	Special group

DOSF_FNEXT	EQU 79		; Find next

;	System group

DOSF_GVOW	EQU 84		; Get verify on write
DOSF_RENAME	EQU 86		; Rename into directory
DOSF_FTIMES	EQU 87		; File write date/time

;	NOTE: All XENIX calls return with 'CY' set if error
;	occurs, and AX = error code. If no error, 'CY' is
;	clear and AX contains returned data

;	The following are 2.0 error codes

DOSE_NOERR	EQU 0		; No error
DOSE_INVFUNC	EQU 1		; Unknown function
DOSE_NOFILE	EQU 2		; File not found
DOSE_NOPATH	EQU 3		; Path not found
DOSE_TMFILES	EQU 4		; Too many open files
DOSE_ACCESS	EQU 5		; Access denied
DOSE_NOHNDL	EQU 6		; Invalid handle
DOSE_ARENA	EQU 7		; Arena trashed (?)
DOSE_NORAM	EQU 8		; Not enough RAM
DOSE_NOBLK	EQU 9		; Bad Block
DOSE_NOENV	EQU 10		; Bad environment (DOSF_EXEC)
DOSE_NOFMT	EQU 11		; Bad format (DOSF_EXEC)
DOSE_INVACC	EQU 12		; Bad Access code
DOSE_INVDAT	EQU 13		; Bad data
DOSE_INVDRV	EQU 15		; Bad drive
DOSE_CURDIR	EQU 16		; Current directory
DOSE_NOTSAM	EQU 17		; Not same device
DOSE_NMFILES	EQU 18		; No more files

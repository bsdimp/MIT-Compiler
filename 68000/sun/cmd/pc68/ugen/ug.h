(* -- UG -- *)

(* Host compiler: *)
  (*%SetT HedrickPascal T *)
  (*%SetF UnixPascal F *)

CONST

   (* Machine Independent *)
   Maxcommons = 50;     (* maximum number of Fortran commons allowed*)
   Novalue = -9999;     (* "Not a number" for Ugenerrors *)
   Lexmax = 16;		(* maximum nesting of procedures *)
   Blkmax = 500;	(* maximum number of procedures per module *)


   (* machine dependent *)

   MachineId = 68000;  (* Integer ID for this machine *)
   IsS1 = False;       (* Which machine? *)
   Is68000 = True;
   IsDec10 = False;
   IsDec20 = False;
   IsVax = False;
   IsMips = False;
   Objext = 'a68';      (* extension for object file name *)

   Binding = True;	(* bind registers in this version? *)
   DownStkLnk = True;	(* Stack grows downwards? *)

   Labchars = 8;        (* signficant characters of label *)
   Labcharsp1 = 9;	(* Labchars plus 1 *)
   Modchars = 5;        (* same, for module names = labchars - 3 *)
   AddrUnit = 8;	(* bits per addressable unit *)
   WordSize = 32;	(* bits per word *)
   APW = 4;		(* address units per word *)

   Localstart = 0;	(* displacement of first local from beginning of
			   stack frame, in AddrUnits *)
   Entrysize = 0;       (* size of extra entry info before the beginning of the    
			   stack frame *)
   Tgtmaxint = Maxint;

   Maxreg = 15;		(* highest register *)
   Fp = 14;		(* frame pointer *)
   Sp = 15;		(* stack pointer *)
   FuncResReg = 0;	(* Function results placed here *)

   Blabl      = '         ';  (* blank label *)
   Bittable   = '_Btabl  X';  (* bit table - single bit *)
   Lmasktable = '_Lmask  X';  (* bit table - ones on left *)
   Rmasktable = '_Rmask  X';  (* bit table - ones on right *)
   Heapptr    = '_Hptr   X';  (* pointer to top of heap *)
   Initolab   = '.L0      ';  (* initial value for Olab in UgSt *)
   Mfiblab    = '_Mfib   X';  (* main file FIB *)

TYPE

   (* machine independent: *)

   (* vars shared by >1  modules *)
   SharedVar = (ShTrace, ShPage, ShLine, ShFastcheck);

   Errstring = PACKED ARRAY [1 .. 30] OF Char;      (* Error messages *)
   Labl = PACKED ARRAY [1 .. Labcharsp1] OF Char;     (* Labels *)

   (* types used in AddrToken: *)
   Consttype =  
      (Notconst, Intconst, Longintconst, Realconst, Longrealconst, Setconst,
       Nilconst, Stringconst, Packedconst, Addrconst, Hexconst, Ascizconst);
   Contexts = (Reference, Literal);
   Fixups = (FNone, FTemps, FFramesize, FNegframesize);
   Tempptr = ^Tlistel; (* Pointer to a expression temporary description *)
   Tlistel = RECORD
      Refcount: Integer; 
      Tmpoffset,                 (*Offset of block in temp area*)
      Tmpsize:          Integer; (*size of block in words      *)
      Next:             Tempptr;
      END;
   Register = -1..Maxreg;
   Regset = Set of 0..Maxreg;

   (* All of the information about what procedure, module, file, etc. we
      are currently compiling is kept by the main block in a Dbginforec,
      which is passed to the routines such as WritPIB which generate tables
      for the debugger. *)

   Dbginforec = RECORD
      Debug: Boolean;
      Profile: Boolean;		  (* Execution timing? *)
      Curprocname: Identname;     (* source name of current procedure *)
      Curproclabl: Labl;          (* Ucode name of current proc *)
      Curpiblab: Labl;            (* label for Pib *)
      Cblk: Integer;		  (* block number of current procedure *)
      Curmodname: Identname;      (* name of current module *)
      Curmodlabl: Labl;           (* label for Mib *)
      Sourcename: Filename;	  (* name of source file *)
      Sourcelabl: Labl;           (* label for Fib *)
      Symbolname: Filename;       (* name of Symbol table file *)
      Proflabl: Labl;             (* label for Profile Table *)
      Filefirstproc: Labl;	  (* first procedure in file *)
      Modfirstproc: Labl;	  (* first procedure in module *)
      Main: Labl;		  (* label of main block, if any *)
      Mainname: Identname;	  (* name of main block, if any *)
      Highestcommon: Integer;     (* number of common areas in this module *)
      Mincreg, Maxcreg: Register; (* ??? *)
      END;

(* intermediate opcodes *)

Icode =
  (Xabs,
   Xadd,Xsub,
   Xcup,
   Xdeposit,Xextractsigned,Xextractunsigned,
   Xfalse,Xtrue,
   Xequ,Xgeq,Xgrt,Xleq,Xles,Xneq,
   Xand,Xnand,Xor,Xnor,Xxor,
   Xandcmp,
   Xexch,
   Xfix,Xfloat,Xrnd,
   Xinc,Xdec,
   Xjump,Xjumplab,
   Xmin,Xmax,
   Xmovadr,Xmove,
   Xmpy,Xdiv,Xmod,Xdivmod,
   Xneg,Xnot,
   Xret,
   Xshift,
   Xstrcmp,
   Xvini,
   Xvmove,
   Xzero,
   Xin, Xnin
   );


   (* machine dependent *)

   Mdatatype = (ILL,SA,QS,HS,SS,DS,QU,HU,SU,SF,DF,M);
   (* Machine datatype.  
      Q = quarterword, H = halfword, S = singleword, D = doubleword, M = multiword.
      A = address, S = signed integer, U = unsigned integer, R = real.
      Note: the order MUST not change, as it is used in initializing tables
    *)
  
   (* address token forms *)

   Forms = (
        Empty,
        Smst,		(* fake "mark stack" used by UGTP *)
	K,		(* constant *)
	R,		(* register *)
	L,		(* address *)
        DR,		(* register displacement *)
	RIInc,		(* Address register with PostIncrement *)
	RIDec,		(* Address register with PreDecrement *)
	RIR,		(* Address register indirect with Index *)
	RI		(* Address register indirect *)
	);				(*Operand names, filled in later*)

   AddrToken = PACKED RECORD
       Mdtype: Mdatatype;  (* machine data type *)
       Form: Forms;	   (* addressing form *)
       Size: Integer;      (* size, in bits, (only if large object *)
       Context: Contexts;  (* whether address or contents of location *)
       Reg: Register;      (* register *)
       Reg2: Register;
       Displ: Integer;	   (* displacement *)
       Labfield: Labl;     (* label, if any *)
       Extlab: Boolean;    (* True if label external to module *)
       Fixup: Fixups;	   (* type of fixup needed *)
       Tmpptr: Tempptr;    (* Pointer to any expr. temp. records 
			      related to the operand*)
       Mtyp: Memtype;	   (* U-code location (for binding) *)
       Bno: Integer;
       Offst: Integer;
       Ctype: Consttype;   (* if constant, tells what type *)
       Cstring: Valu;      (* string representation of constant *)
    END;
 
   (* target machine instructions *)

Ocode =
   (
   (* Fakeops *)
   Ploc,Pstart,Plab,Pillegal,Pnop,
   (* Data movement operations *)
	movb,	movw,	movl,	movemw,	moveml,	moveq,
	exg,	swap,	link,	unlk,	lea,	pea,
   (* Integer arithmetic operations *)
	(*-*)	addaw,	addal,	addb,	addw,	addl,
	addib,	addiw,	addil,	addqb,	addqw,	addql,
	(*-*)	subaw,	subal,	subb,	subw,	subl,
	subib,	subiw,	subil,	subqb,	subqw,	subql,
	muls,	mulu,	divs,	divu,
	negb,	negw,	negl,	(*-*)	extw,	extl,
	clrb,	clrw,	clrl,
	(*-*)	cmpaw,	cmpal,	cmpb,	cmpw,	cmpl,
	cmpib,	cmpiw,	cmpil,	cmpmb,	cmpmw,	cmpml,
	tstb,	tstw,	tstl,
   (* Logical operations *)
	andb,	andw,	andl,	andib,	andiw,	andil,
	orb,	orw,	orl,	orib,	oriw,	oril,
   	eorb,	eorw,	eorl,	eorib,	eoriw,	eoril,
	notb,	notw,	notl,
   (* Shifts *)
	aslb,	aslw,	asll,	asrb,	asrw,	asrl,
	lslb,	lslw,	lsll,	lsrb,	lsrw,	lsrl,
	rolb,	rolw,	roll,	rorb,	rorw,	rorl,
   (* Bit manipulation operations *)
   	btstb,	(*-*)	btstl,	bchgb,	(*-*)	bchgl,
	bsetb,	(*-*)	bsetl,	bclrb,	(*-*)	bclrl,
   (* Program control *)
	dbf,	dbne,	bra,	jmp,	jsr,	rts,
	scc,scs,seq,sfalse,sge,sgt,shi,sle,sls,slt,smi,sne,spl,strue,svc,svs,
	jcc,jcs,jeq,jge,jgt,jhi,jle,jls,jlt,jmi,jne,jpl,jvc,jvs,jra,
	chk,trap
   )  ;

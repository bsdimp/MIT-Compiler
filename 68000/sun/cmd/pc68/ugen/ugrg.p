(* ~/upas differences: Rum[-1] := Specialpurpose
	Savestack is included
	Freeworkreg is strange
	and ?
 *)
(* -- UGRG.PAS -- *)  
(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%iff UnixPascal*)
{  (*$M-*)}
{}
{  PROGRAM UGRG;}
{}
{     INCLUDE 'Ucode.Inc';}
{     INCLUDE 'Ug.Inc';}
{     INCLUDE 'Ugat.Imp';}
{     INCLUDE 'Ugcd.Imp';}
{     INCLUDE 'Ugsp.Imp';}
(*%else*)
#include "ucode.h";
#include "ug.h";
#include "ugat.h";
#include "ugcd.h";
#include "ugsp.h";
#include "ugrg.h";
(*%endc*)

(* This module has control over the registers, the stack, and the temporaries.

   See UGEN Documenvided into at most two CLASSES: General purpose registers
   and Special registers that are used for one data type only (addresses, 
   floating point,
   etc.).  For each class, there is a map containing various kinds of information
   about the registers of a certain class.  This is kept in the RCM (register
   class map.)

   Registers have three kinds of USES:  either they are WORK registers, which may
   be allocated by routines in this module to hold temporary expression results,
   or they are SPECIALPURPOSE registers, such as the PC, FP, SP, etc. or they are
   RESERVED registered, which are allocated in the U-code to hold 
   variables.
   The Use of a register, as well as other data, such as whether or not it is
   currently in use, is kept in the RUM (register usage map).   This is an
   array going from -1 to N-1, where N is the total number of registers in the
   machine that will ever appear in the assembly code (including PC, etc.).

   The stack is a doubly linked list or address tokens.  New records are allocated 
   when necessary during a Push, but they are not Diposed during a Pop.
   Instead, they are kept in the list and re-used when the next Push occurs.
   
   Temporaries are also kept in a linked list.   When a new temporary is needed,
   the list is first searched to see if there has been one already allocated
   of exactly the right size.  If not, it is allocated on the stack (by increasing
   Tempsize).  The temporary routines are very simple; more complicated ones
   that would do a better job of re-using old space are probably not worth it.

*)


TYPE

   Uses = (Work, Reserved, Specialpurpose);

   Pairtypes = (Single,			(*Register is not member of a pair *)
		Firstofpair,		(*Register is first of a pair*)
		Secondofpair);	        (*Register is second of a pair*)

   Regbinding =  (* the U-code data object contained by a work register, if any *)
                 (* or, if Blkno is negative, the level for the display pointer that
		    this register holds *)
      RECORD	 
      Mtype: Memtype;
      Blkno, Offset: Integer
      END;
		   

   (* Each element of the virtual stack contains one addrtoken. *)
   Stackptr = ^Stackelement;
   Stackelement = 
               RECORD
               Snext, Slast: Stackptr;
               At: Addrtoken;
               END;

VAR
   (* Temporary management variables: *)

   Maxtmp: Integer;             (* The greatest temporary Offset allocated*)
                                (* in the module so far                   *)
   Firsttemp,Lasttemp: Tempptr;

   (* Register usage map *)
   Rum: ARRAY [-1..Maxreg] OF 
      RECORD
      Refcount: Integer;         (* The number of address tokens that refer
				    to the register *)
      Pairtype: Pairtypes;       (* Single,Firstofpair,Secondofpair*)
      Valid: Boolean;            (* True if the register is bound*)
      Use: Uses;                 (* Current use of the register*)
      Contents: Regbinding;      (* Location bound to this register*)
      END;

   Regclasses: Integer;	         (* 1 or 2 register classes? *)
   Class2type: Mdatatype;        (* The Mdata type of data objects that should go
			            into the Special register class. *)

   (* Register class map *)
   Rcm: ARRAY [False..True] OF
      RECORD
      FirstR,	   	(* first register -- readonly *)
      LastR,		(* last register -- readonly *)
      Firstcallersave,  (* first callersave reg -- readonly *)
      Lastcallersave,   (* last callersave reg -- readonly *)
      Lastvar,		(* last variable register -- readonly *)
      Firstvar,         (* first (lowest) variable reg *)
      Highwork,		(* highest calleesave work reg = Firstvar - 1*)
      Lowwork,	 	(* lowest calleesave work reg -- readonly *)
      Lastal: Register;	(* last callersave register allocated *)

      Roffset,		(* U-code offset of first register *)
      MaxVars: Integer; (* maximum number of variables allowed -- readonly *)
      END;

   Boundcount: Integer; (* number of registers currently bound *)
   Regsused: Regset;    (* the set of registers that must be saved on preocedure
			   entry *)
   Callersaveregs: Regset; (* the set of registers that must be saved by the
			      caller (readonly) *)
   (* statistics: *)
   Bindcnt: Integer; (* Counts the number of register loads saved by binding. *)
   Loadcnt: Integer; (* The total number of registers loaded*)

   Treguse: Boolean; (* print register optimization statistics *)
   Ttemps: Boolean;  (* trace use of temporaries *)

   (* the stack *)
   Tos: Stackptr;                              (*Top Of virtual stack.*)

 
(* exported procedures *)

(*%iff UnixPascal*)
{}
{PROCEDURE Initrg;}
{   FORWARD;}
{}
{PROCEDURE CopyAt (VAR Dest, Source: Addrtoken);}
{   FORWARD;}
{}
{PROCEDURE Inittemps;}
{   FORWARD;}
{}
{PROCEDURE SetRgVar (Varbl:SharedVar; Val: Integer);}
{   FORWARD;}
{}
{FUNCTION GetMaxtmp: Integer;}
{   FORWARD;}
{}
{PROCEDURE Getstats (VAR Bcount, Lcount: Integer);}
{   FORWARD;}
{}
{PROCEDURE Returnreg (Rg: Register);}
{   FORWARD;}
{}
{PROCEDURE Clean (At: Addrtoken);}
{   FORWARD;}
{}
{PROCEDURE Push (At: Addrtoken);}
{   FORWARD;}
{}
{PROCEDURE Pop (VAR At : Addrtoken);}
{   FORWARD;}
{}
{PROCEDURE Emptystack;}
{   FORWARD;}
{}
{FUNCTION IsWorkReg (VAR At: Addrtoken): Boolean;}
{   FORWARD;}
{}
{FUNCTION WorkReg (Rg: Register): Boolean;}
{   FORWARD;}
{}
{FUNCTION IsFree (Rg: Register): Boolean;}
{   FORWARD;}
{}
{FUNCTION PairFree (Rg: Register): Boolean;}
{   FORWARD;}
{}
{FUNCTION SoleUser (Rg: Register): Boolean;}
{   FORWARD;}
{}
{PROCEDURE ReserveRegs (Regclass, Offset, Size: Integer; VAR Dbginfo: Dbginforec);}
{   FORWARD;}
{}
{FUNCTION Regno (Offset: Integer): Register;}
{   FORWARD;}
{}
{PROCEDURE Freeworkreg (Rg: Register);}
{   FORWARD;}
{}
{PROCEDURE SplitAt (VAR Oldat, At1, At2: Addrtoken);}
{   FORWARD;}
{}
{FUNCTION Alocateregpair (Mdtyp: Mdatatype): Register;}
{   FORWARD;}
{}
{FUNCTION Allocatereg (Mdtyp: Mdatatype): Register;}
{   FORWARD;}
{}
{PROCEDURE GetThatReg (Rg: Register; Mdtyp: Mdatatype);}
{   FORWARD;}
{}
{PROCEDURE Grabreg (Rg:Register);}
{   FORWARD;}
{}
{PROCEDURE Grabpair (Rg:Register);}
{   FORWARD;}
{}
{PROCEDURE Killreg (Rg:Register);}
{   FORWARD;}
{}
{PROCEDURE Bindreg (Rg: Register; Mty: Memtype; Blk, Offst: Integer);}
{   FORWARD;}
{}
{FUNCTION Matchreg (Mdtype: Mdatatype; Mty: Memtype; Blk, Offst: Integer; VAR Vreg: Register;}
{		    MultiplerefOk: Boolean): Boolean;}
{   FORWARD;}
{}
{PROCEDURE Killloc(Mty: Memtype; Blk, Offst: Integer);}
{   FORWARD;}
{}
{PROCEDURE Killbindings;}
{   FORWARD;}
{}
{PROCEDURE Basicblock (Alldead: Boolean);}
{   FORWARD;}
{}
{PROCEDURE Loadstack;}
{   FORWARD;}
{}
{PROCEDURE Callerregs (VAR Rgs: Regset);}
{   FORWARD;}
{}
{PROCEDURE Calleeregs (VAR Rgs: Regset);}
{   FORWARD;}
{}
{FUNCTION Recycletemp (Size: Integer): Tempptr;}
{   FORWARD;}
{}
{PROCEDURE Gettemp (VAR Tptr: Tempptr; Size: Integer; VAR Tlb: Integer);}
{   FORWARD;}
{}
{FUNCTION Expandtemp (VAR At: Addrtoken; NewSize: Integer): Boolean;}
{   FORWARD;}
{}
(*%endc*)


PROCEDURE Initrg{};

   (* Called at the very beginning to initialize this module. *)

   VAR Rg: Register;

   BEGIN
   Firsttemp := NIL;

   New (Tos);
   WITH Tos^ DO
      BEGIN
      Slast := NIL;
      Snext := NIL;
      At.Form := Smst;
      At.Size := 0;
      END;

   FOR Rg := -1 TO Maxreg DO
      WITH Rum[Rg] DO
         BEGIN
	 Refcount := 0;
	 Use := Work;
	 Pairtype := Single;
	 Valid := False;
	 END;

   IF IsS1 THEN
      BEGIN
      Rum[-1].Use := Specialpurpose;
      Rum[ 0].Use := Specialpurpose;
      Rum[ 3].Use := Specialpurpose;
      Rum[FP-1].Use := Specialpurpose;
      Rum[FP].Use := Specialpurpose;
      Rum[SP].Use := Specialpurpose;
      Callersaveregs := [0,1,2,3,4,5,6,7];
      Regclasses := 1;
      Class2type := ILL;
      WITH Rcm[False] DO
	 BEGIN
	 FirstR := 1;
	 LastR := FP-2;
         Firstcallersave := 1;
         Lastcallersave := 7;
	 Lastvar := LastR;
	 Lowwork := 8;
	 MaxVars := 10;
	 END
      END
   ELSE IF IsDec10 THEN
      BEGIN
      Rum[-1].Use := Specialpurpose;
      Rum[ 0].Use := Specialpurpose;
      Rum[SP].Use := Specialpurpose;
      Callersaveregs := [0,1,2,3,4];
      Regclasses := 1;
      Class2type := ILL;
      WITH Rcm[False] DO
	 BEGIN
	 FirstR := 1;
	 LastR := 14;
	 Firstcallersave := 1;
	 Lastcallersave := 4;
	 Lastvar := 14;
	 Lowwork := 5;
	 MaxVars := 10;
	 END
      END
   ELSE IF Is68000 THEN
      BEGIN
      Rum[-1].Use := Specialpurpose;
      Rum[FP].Use := Specialpurpose;
      Rum[SP].Use := Specialpurpose;
      Callersaveregs := [0,1,8,9]; (* d0, d1, a0, a1 *)
      Regclasses := 2;
      Class2type := Sa;
      WITH Rcm[False] DO
	 BEGIN
	 FirstR := 0;
	 LastR := 7;
	 Firstcallersave := 0;
	 Lastcallersave := 1;
	 Lastvar := 7;
	 Lowwork := 2;
	 MaxVars := 3;
	 END;
      WITH Rcm[True] DO
	 BEGIN
	 FirstR := 8;
	 LastR := 13;
	 FirstCallersave := 8;
	 LastCallersave := 9;
	 Lastvar := 13;
	 Lowwork := 10;
	 MaxVars := 2;
	 END;
      END;
   Treguse := False;
   Ttemps := False;
   Bindcnt := 0;
   Loadcnt := 0;
   END;

PROCEDURE CopyAt {(VAR Dest, Source: Addrtoken)};
  BEGIN
  Dest := Source;
  WITH Source DO
     BEGIN
     IF Reg <> -1 THEN
	WITH Rum[Reg] DO
	   IF (Refcount <= 0) AND (Use = Work) THEN
	      BEGIN
	      Ugenerror ('Copying un-allocated register:',Reg);
	      Refcount := 2;
	      END
           ELSE Refcount := Refcount + 1;
     IF Reg2 <> -1 THEN
	WITH Rum[Reg2] DO
	   IF (Refcount <= 0) AND (Use = Work) THEN
	      BEGIN
	      Ugenerror ('Copying un-allocated register:',Reg2);
	      Refcount := 2;
	      END
           ELSE Refcount := Refcount + 1;
     IF Tmpptr <> NIL THEN
	WITH Tmpptr^ DO
	   IF Refcount <= 0 THEN
	      BEGIN
	      Ugenerror ('Copying un-allocated temporary',Tmpoffset);
	      Refcount := 2;
	      END
           ELSE Refcount := Refcount + 1;
     END;
   END;

PROCEDURE Inittemps{};

   (* Called at the beginning of each procedure to re-initialize this
      module. *)

   VAR Rg: Register;
       Savedptr: Tempptr;
       B: Boolean;
   BEGIN
   (* Resets the temp allocation variables *)
   WHILE Firsttemp <> NIL DO
      BEGIN
      Savedptr := Firsttemp;
      Firsttemp := Firsttemp^.Next;
      Dispose (Savedptr);
      END;
   Lasttemp := NIL;
   Maxtmp := 0;
   FOR Rg := 0 to Maxreg DO
      IF Rum[Rg].Use = Reserved THEN 
	 Rum[Rg].Use := Work;
   FOR B := False TO (Regclasses = 2) DO
      WITH Rcm[B] DO
	 BEGIN
	 Highwork := Lastvar;
	 Lastal := Lastcallersave;
	 Roffset := -1;
	 END;

   Boundcount := 0;
   Regsused := [];

   WITH Rcm[True] DO
      BEGIN
      Roffset := 999999;
      END;

   END;

(* interface routines *)

PROCEDURE SetRgVar {(Varbl:SharedVar; Val: Integer)};
   BEGIN
   IF Varbl = ShTrace THEN
      BEGIN
      TregUse := Odd (Val DIV 8);
      Ttemps := Odd (Val DIV 16);
      END;
   END;

FUNCTION GetMaxtmp{: Integer};
   BEGIN
   GetMaxtmp := Maxtmp;
   END;

PROCEDURE Getstats {(VAR Bcount, Lcount: Integer)};

   BEGIN
   Bcount := Bindcnt;
   Lcount := Loadcnt;
   END;

(* Returnreg Clean *)

PROCEDURE Returnreg {(Rg: Register)};

(* Used to mark a work register as being unused.  It may
   be passed any register (including -1), and it will only free the register
   if it is a work register. If the register is the first register of a pair,
   both registers are freed, an marked as single registers. *)


   BEGIN

   IF (Rum[Rg].Use = Work) THEN 
      BEGIN
      IF Rum[Rg].Refcount <= 0 THEN 
         UgenError ('Returning unused reg          ',Rg) 
      ELSE 
	 Rum[Rg].Refcount := Rum[Rg].Refcount - 1;
      IF Rum[Rg].Refcount = 0 THEN
	 IF Rum[Rg].Pairtype = Firstofpair THEN
	    BEGIN
	    Rum[Rg+1].Refcount := 0;
	    Rum[Rg+1].Pairtype := Single;
	    Rum[Rg].Pairtype := Single;
	    END
      END;
   END;

PROCEDURE Clean {(At: Addrtoken)};

(* This routine releases any work registers or temporaries used by At. *)

   BEGIN
   WITH At DO 
      BEGIN
      IF Tmpptr <> NIL THEN
	 BEGIN
	 IF Tmpptr^.Refcount <= 0 THEN
	    UgenError ('Returning unused temp.        ',Tmpptr^.Tmpoffset)
	 ELSE 
	    BEGIN
     	    Tmpptr^.Refcount := Tmpptr^.Refcount - 1;
	    IF Ttemps THEN
	       UgenMsg ('Returning temp.               ',Tmpptr^.Tmpoffset);
	    END
	 END;
      Returnreg (Reg);
      Returnreg (Reg2);
      END;
   END (* clean *);

(* Push Pop EmptyStack *)

PROCEDURE Push {(At: Addrtoken)};
   VAR
      Sptr: Stackptr;
   BEGIN
   Sptr := Tos^.Slast;
   IF Sptr = NIL THEN
      BEGIN
      New (Sptr);
      Sptr^.Slast := NIL;
      Sptr^.Snext := Tos;
      Tos^.Slast := Sptr;
      END;
   Sptr^.At := At;
   Tos := Sptr;
   END;

PROCEDURE Pop {(VAR At : Addrtoken)};

   BEGIN
   IF Tos = NIL THEN UgenError ('Nothing to pop!               ', Novalue)
   ELSE
      BEGIN
      At := Tos^.At;
      Tos := Tos^.Snext;
      END;
   END;

PROCEDURE Emptystack{};

   (* Called when the stack should be empty.  If it is
      not, it prints an error message and cleans it up. *)

   VAR At: Addrtoken;

   BEGIN
   IF Tos^.At.Form <> Smst THEN
      BEGIN
      UgenError ('Stack not empty.              ',Novalue);
      Repeat
	 Pop(At);
	 Clean(At);
	 IF Tos = NIL THEN
            BEGIN
            At.Form := Smst;
            Push(At);
	    END;
      UNTIL Tos^.At.Form = Smst;
      END;
   END;

FUNCTION IsWorkReg {(VAR At: Addrtoken): Boolean};
   BEGIN
   IsWorkReg := (At.Form = R) AND (Rum[At.Reg].Use = Work);
   END;

FUNCTION WorkReg {(Rg: Register): Boolean};
   BEGIN
   WorkReg := (Rum[Rg].Use = Work);
   END;

FUNCTION IsFree {(Rg: Register): Boolean};
   BEGIN
   IsFree := (Rum[Rg].Use = Work) AND (Rum[Rg].Refcount = 0);
   END;

FUNCTION PairFree {(Rg: Register): Boolean};
   BEGIN
   PairFree := (Rum[Rg].Use = Work) AND (Rum[Rg].Refcount = 0) AND
             (Rum[Rg+1].Use = Work) AND (Rum[Rg+1].Refcount = 0);
   END;

FUNCTION SoleUser {(Rg: Register): Boolean};
   BEGIN
   SoleUser := (Rum[Rg].Refcount = 1);
   END;

(* ReserveRegs Regno *)

PROCEDURE ReserveRegs {(Regclass, Offset, Size: Integer; VAR Dbginfo: Dbginforec)};

   (* At the beginning of a procedure, a certain number of registers may
      be reserved for locals via the REGS instruction.  This routine is
      called to mark the registers as Reserved and to establish the mapping
      between U-code offset and Rum number. *)

   VAR Rg: Register;

   BEGIN
   IF (Regclass < 1) OR (Regclass > Regclasses) THEN
      Ugenerror ('Illegal register class.       ', Regclass)
   ELSE WITH Rcm[Regclass > 1] DO
      BEGIN
      IF Size DIV APW > Maxvars THEN
	 BEGIN
	 Ugenerror ('Too many registers reserved.  ', Size DIV APW);
	 Size := Maxvars;
         END;
      Roffset := Offset;
      Firstvar := Lastvar - Size DIV APW + 1;
      Highwork := Firstvar - 1;
      FOR Rg := Firstvar TO  Lastvar DO
	 BEGIN
         Rum[Rg].Use := Reserved;
         (* these regs must be saved on proc entry *)
         Regsused := Regsused + [Rg]; 
         END;
      END;
   END;

FUNCTION Regno {(Offset: Integer): Register};

   (* Given a U-code offset (IN BITS!), translates to the correct
      register number. *)

   VAR Rg: Integer;

   BEGIN
   WITH Rcm[Offset >= Rcm[True].ROffset] DO
      BEGIN
      Rg := Firstvar + (Offset - Roffset) DIV Wordsize;
      IF (Rg > Lastvar) THEN
	 BEGIN
         Ugenerror ('Illegal register offset       ', Offset);
	 Regno := -1;
	 END
      ELSE 
	 BEGIN
	 Regno := Rg;
	 Regsused := Regsused + [Rg];
	 END;
      END;
   END;

PROCEDURE Freeworkreg {(Rg: Register)};

(* This routine is called if all registers are in use and one is needed.  The 
   stack item using the register is loaded and moved to a temporary location,
   freeing the register. *)

   LABEL 99;
   VAR
      TempAt: Addrtoken;
      Sptr: Stackptr;

   BEGIN


   (* Find the reg stack token. *)
   Sptr := Tos;
   WHILE Sptr <> NIL DO 
      BEGIN
      WITH Sptr^.At DO
         IF NOT (Form IN [Empty,Smst]) THEN
	    IF (Reg = Rg) OR (Reg2 = Rg) THEN GOTO 99;
      Sptr := Sptr^.Snext;
      END;
99:IF Sptr = NIL THEN 
      Ugenerror ('Work reg token not found.     ',Rg)
   ELSE 
      WITH Sptr^, At DO
         BEGIN
	 IF (Form = RI) AND (Context = Literal) THEN
	    BEGIN Form:= R; Context:= Reference END;
         IF Context = Literal THEN
	    IF (Form IN [DR,RIR]) AND (Rum[Reg].Refcount <= 1) THEN
	       BEGIN
	       Form:= R; Context:= Reference;
	       IF Displ <> 0 THEN
	          BEGIN
	          MakintconstAt (TempAt, Displ); Displ := 0;
		  Emitbinaryop (Xadd, At, At, TempAt)
		  END;
               MakregAt (TempAt, Ss, Reg2);
	       IF Form = RIR THEN Emitbinaryop (Xadd, At, At, TempAt);
	       Clean (TempAt);
	       END;
         IF Rum[Rg].Refcount > 0 THEN
	    BEGIN
	    IF (Context = Literal) AND (Form IN [DR, RIR]) THEN
	       BEGIN
	       Emit1 (pea, At); Clean (At);
	       MakregAt (At, At.Mdtype, Sp);
	       At.Form:= RIInc;
	       END;
	    MakTempAt (TempAt, At.Mdtype, APW, Reference);
            Moveit (TempAt, At);
            At := TempAt;
	    END;
         END;
   IF Rum[Rg].Refcount > 0 THEN
      Ugenerror ('Trying to free mult. ref.reg. ',Rg);
   IF Rum[Rg].Valid THEN
      BEGIN
      Boundcount := Boundcount - 1;
      Rum[Rg].Valid := False;
      END;
   END;

PROCEDURE SplitAt {(VAR Oldat, At1, At2: Addrtoken)};

   (* OldAt contains a register pair.  Split this into two address token, each
      containing one register. *)

   BEGIN
   IF (OldAt.Form <> R) THEN
      Ugenerror ('Splitting non-register.       ',Ord(oldAt.Form));
   IF (OldAt.Mdtype <> Ds) AND NOT (Is68000 AND (OldAt.Mdtype = Df)) THEN
      Ugenerror ('Splitting non-pair.           ',Ord(oldAt.mdtype));
   At1 := OldAt;
   At1.Mdtype := Ss;
   At2 := At1;
   At2.Reg := At1.Reg + 1;
   IF OldAt.Mdtype = Df THEN At1.Mdtype := Sf;
   IF (Rum[At1.Reg].Pairtype <> Firstofpair) THEN
      Ugenerror ('Splitting non-pair!           ',Novalue);
   Rum[At1.Reg].Pairtype := Single;
   Rum[At2.Reg].Pairtype := Single;
   END;

FUNCTION Alocateregpair {(Mdtyp: Mdatatype): Register};

(* Same as Allocatereg, but gets a pair. *)

   LABEL 99;
   VAR
      Rg: Register;

   BEGIN
   WITH Rcm [Mdtyp=Class2type] DO
      BEGIN

      (* First, try any free callersavereg *)
      FOR Rg := Firstcallersave TO Lastcallersave-1 DO
	 IF (Rum[Rg].Refcount = 0) AND (Rum[Rg+1].Refcount = 0) AND
            (Rum[Rg].Use = Work) AND (Rum[Rg+1].Use = Work) THEN
	    BEGIN
	    Lastal := Rg + 1; GOTO 99;
	    END;

      (* Next, try any free reg *)
      FOR Rg := Highwork-1 DOWNTO Lowwork DO
	 IF (Rum[Rg].Refcount = 0) AND (Rum[Rg+1].Refcount = 0) AND
	    (Rum[Rg].Use = Work) AND (Rum[Rg+1].Use = Work) THEN
	    BEGIN
	    GOTO 99;
	    END;

      (* If a free register still can't be found then free up a callersave reg. *)
      IF Treguse THEN
         Ugenmsg ('Freeing work register pair.   ',Firstcallersave);

      Rg := Firstcallersave;
      Freeworkreg (Rg);
      Freeworkreg (Rg+1);

   (* Return the allocated register *)
   99:
      WITH Rum[Rg] DO
	 BEGIN
         Pairtype := Firstofpair;
         Refcount := 1;
         IF Valid THEN 
	    BEGIN
	    Valid := False; Boundcount := Boundcount - 1;
	    END;
         IF NOT (Use = Work) THEN
	    Ugenerror ('Allocating non-work register..',Rg)
	 END;
      WITH Rum[Rg+1] DO
	 BEGIN
         Pairtype := Secondofpair;
         Refcount := 1;
         IF Valid THEN 
	    BEGIN
	    Valid := False; Boundcount := Boundcount - 1;
	    END;
         IF NOT (Use = Work) THEN
	    Ugenerror ('Allocating non-work register..',Rg+1)
	 END;
      Regsused := Regsused + [Rg,Rg+1];
      Alocateregpair := Rg;
      END;
   END;

FUNCTION Allocatereg {(Mdtyp: Mdatatype): Register};

(* This routine call AlocateRegPair if the data type indicates that a pair is
   needed.  Otherwise it allocates a work register, in the following order:

        1. The oldest callersave register that is free and not bound.
        2. Any callersave register.
	3. The highest free calleesave register.

   If no registers are free, it spills the oldest callersave register and uses
   that.
*)
   LABEL 99;
   VAR
      Rg, First, Last: Register;


   BEGIN

   IF Mdtyp IN [Df, Ds] THEN
      AllocateReg := AlocateRegPair (Mdtyp)

   ELSE WITH Rcm [Mdtyp = Class2type] DO
      BEGIN
      (* Start with first work register following the last one allocated. *)

      Last := Lastal;
      First := Succ(Last); 
      IF First > Lastcallersave THEN First := Firstcallersave;

      (* First look for a free callersave register which is not bound. *)
      Rg := First;
      WHILE (Rg <> Last) DO
	 WITH Rum[Rg] DO
	    IF (Refcount = 0) AND (NOT Valid) AND (Use = Work) THEN
	       BEGIN
	       Lastal := Rg; GOTO 99;
	       END
	    ELSE 
	       BEGIN
	       Rg := Succ(Rg);
     	       IF Rg > Lastcallersave THEN Rg := Firstcallersave;
	       END;

      (* Nope, look for any free callersave register *)
      FOR Rg := Firstcallersave TO Lastcallersave DO
	 IF (Rum[Rg].Refcount = 0) AND (Rum[Rg].Use = Work) THEN 
	    BEGIN
            Lastal := Rg; GOTO 99 
	    END;

      (* Nope, look for any register *)
      FOR Rg := Highwork DOWNTO Lowwork DO
	 IF (Rum[Rg].Refcount = 0) THEN 
            GOTO 99;

      (* Nope, free up the oldest callersave register. *)
      IF Treguse THEN
         Ugenmsg ('Freeing work register.        ',First);
      Freeworkreg (First);
      Rg := First;

   (* Return the allocated register *)
   99:
      Allocatereg := Rg;
      WITH Rum[Rg] DO
	 BEGIN
         Refcount := 1;
	 IF Valid THEN
	    BEGIN
	    Valid := False; Boundcount := Boundcount - 1;
	    END;
	 IF NOT (Use = Work) THEN
	    Ugenerror ('Allocating non-work register. ',Rg)
	 END;
      Regsused := Regsused + [Rg];
      END;
   END;

(* Grabreg Getthatreg Grabpair Killreg *)

PROCEDURE GetThatReg {(Rg: Register; Mdtyp: Mdatatype)};
   (* Allocates a certain register, saving it in a temp if it is already in use. *)
   BEGIN
   IF Mdtyp IN [Ds,Df] THEN
      BEGIN
      IF Rum[Rg].Refcount > 0 THEN Freeworkreg (Rg);
      IF Rum[Rg+1].Refcount > 0 THEN Freeworkreg (Rg+1);
      Rum[Rg+1].Refcount := 1;
      Rum[Rg].Pairtype := Firstofpair;
      Rum[Rg+1].Pairtype := Secondofpair;
      END
   ELSE
      Freeworkreg (Rg);
   Rum[Rg].Refcount := 1;
   END;

PROCEDURE Grabreg {(Rg:Register)};
   (* Used to allocate a specific register that is believed 
      to be already free. *)

   BEGIN
   WITH Rum[Rg] DO
      BEGIN
      IF Refcount <> 0 THEN
         UgenError ('Grabbing unfree register.     ',Rg);
      Refcount := Refcount + 1;
      END;
   Regsused := Regsused + [Rg];
   END;

PROCEDURE Grabpair {(Rg:Register)};
   (* Used to allocate a specific register pair that is believed 
      to be already free. *)

   BEGIN
   WITH Rum[Rg] DO
      BEGIN
      IF Refcount <> 0 THEN
         UgenError ('Grabbing unfree register.     ',Rg);
      Refcount := Refcount + 1;
      Pairtype := Firstofpair;
      END;
   WITH Rum[Rg+1] DO
      BEGIN
      IF Refcount <> 0 THEN
         UgenError ('Grabbing unfree register.     ',Rg);
      Refcount := Refcount + 1;
      Pairtype := Secondofpair;
      END;
   Regsused := Regsused + [Rg,Rg+1];
   END;

PROCEDURE Killreg {(Rg:Register)};

   (* Mark reg contents not valid, that is destroys any bindings associated with
      the specified register. *)

   BEGIN
   WITH Rcm [Rg > Rcm[False].Lastr] DO
      IF Rum[Rg].Valid THEN 
	 BEGIN
	 Boundcount := Boundcount - 1; Rum[Rg].Valid := FALSE;
	 END;
   END;

PROCEDURE Bindreg {(Rg: Register; Mty: Memtype; Blk, Offst: Integer)};

  (* Bind a register to a U-code memory location. *)

   VAR
      I: Integer;

   BEGIN
   WITH Rum[Rg], Contents, Rcm[Rg > Rcm[False].Lastr] DO
      BEGIN
      Mtype := Mty;
      Blkno := Blk;
      Offset := Offst;
      Valid := True;
      END;
   Boundcount := Boundcount + 1;
   END;

(* Matchreg *)

(* This routine scans through the register usage map attempting to find
   a register that is free and that contains the contents of the U-code
   location indicated by the U-code instrucuction U.
   Returns number of register, or -1 if no match found.*)

FUNCTION Matchreg {(Mdtype: Mdatatype; Mty: Memtype; Blk, Offst: Integer; VAR Vreg: Register;
		    MultiplerefOk: Boolean): Boolean};

   LABEL 99;
   VAR
      I: Integer;

   BEGIN
   Vreg := -1;
   
   WITH Rcm [Mdtype = Class2type] DO
      IF Boundcount > 0 THEN
	  FOR I := FirstCallerSave TO LastCallerSave DO
	     WITH Rum[I] DO
		IF (Refcount = 0) OR MultipleRefOK THEN
		   IF Valid THEN
		      IF Contents.Offset = Offst THEN
			 IF (Contents.Mtype = Mty) AND 
			    (Contents.Blkno = Blk) THEN
			 BEGIN
			 Vreg := I;
			 Refcount := Refcount + 1;
			 GOTO 99;
			 END;

99:IF Treguse THEN
      BEGIN
      Loadcnt := Loadcnt + 1;
      IF Vreg <> -1 THEN
	 BEGIN
	 UgenMsg ('Bound register re-used.       ',Vreg);
	 Bindcnt := Bindcnt + 1;
	 END
      END;
   Matchreg := Vreg <> -1;
   END;
   
(* Killbindings, Killloc, Basicblock *)

PROCEDURE Killloc{(Mty: Memtype; Blk, Offst: Integer)};
   (* Kill all bindings to a given U-code location. *)

   VAR B: Boolean;
       I: Integer;

   BEGIN
   IF Boundcount > 0 THEN
      FOR B := False TO (Regclasses = 2) DO
         WITH Rcm[B] DO
	    FOR I := FirstCallerSave TO LastCallersave DO
	       WITH Rum[I] DO
		  IF Valid THEN
		     IF Contents.Offset = Offst THEN
			IF (Contents.Mtype = Mty) AND (Contents.Blkno = Blk) THEN
			   BEGIN
			   Valid := False;
			   Boundcount := Boundcount - 1;
			   END;
   END;


PROCEDURE Killbindings{};

   (* Mark bindings between registers and memory locations not valid.
      This is called when an unknown location in memory is altered; e.g.
      ISTR;  Display pointers and Constants are still valid, but other
      bindings may be invalid;  if SAFE is true, then ALL other bindings
      are marked invalid;  otherwise, the only case we need to worry about
      up-level aliasing, where an up-level variable is passed by reference,
      in which case it might be affected by an ISTR *)

   VAR Rg: Register;
       B: Boolean;

   BEGIN
   IF Boundcount > 0 THEN
      FOR B := False TO (Regclasses = 2) DO
         WITH Rcm[B] DO
	    FOR Rg := FirstCallersave TO Lastcallersave DO
	       Rum[Rg].Valid := False;
   Boundcount := 0;
   END;

PROCEDURE Basicblock {(Alldead: Boolean)};

   (* Marks ALL register bindings invalid;  this occurs at every basic block
      boundary.  If Alldead is true, there should be no active registers.
      *)

   VAR Rg: Register;
       B: Boolean;

   BEGIN
   FOR B := False TO (Regclasses = 2) DO
      WITH Rcm[B] DO
	 BEGIN
	 FOR Rg := FirstR TO LastR DO
	    BEGIN
	    IF Alldead AND (Rum[Rg].Refcount <> 0) THEN 
	       BEGIN
	       UgenError ('Reg still active at b. block. ',Rg);
	       Rum[Rg].Refcount := 0;
	       END;
	    Rum[Rg].Valid := False;
	    END;
	 IF Alldead THEN
	    Lastal := Lastcallersave;
	 END;
   Boundcount := 0;
   END;

PROCEDURE Loadstack{};

   (* * Guarantees that every item on the stack is either a constant, work register,
      or temporary.  This is necessary at Nstrs and Bgnbs to prevent side 
      effects. * *)

   VAR
      Sptr : Stackptr;
   BEGIN
   Sptr := Tos;
   WHILE (Sptr^.At.Form <> Smst) DO
     BEGIN
     IF NOT Isworkreg (Sptr^.At) AND (Sptr^.At.Ctype = Notconst) AND NOT
 	Istemp (Sptr^.At) THEN
           Loadreg (Sptr^.At);
     Sptr := Sptr^.Snext;
     END;
   END;

PROCEDURE Callerregs {(VAR Rgs: Regset)};

(* This routine finds all the callersave regs that are currently in use. *)

   VAR
      B: Boolean;
      Rg: Register;

   BEGIN
   Rgs := [];
   IF (Tos^.Slast <> NIL) THEN
      FOR B := False TO (Regclasses = 2) DO
	 WITH Rcm[B] DO
            FOR Rg := Firstcallersave TO LastCallersave DO
	          WITH Rum[Rg] DO
		     IF (Use = Work) AND (Refcount <> 0) THEN
			Rgs := Rgs + [Rg];
   END;


PROCEDURE Calleeregs {(VAR Rgs: Regset)};
(* This routine returns all the calleesave regs that have ever been used in
   the current procedure. *)
   BEGIN
   Rgs := Regsused - Callersaveregs;
   END;

PROCEDURE Savestack{};

(* This routine is called at a procedure call.  It goes through the stack 
   and saves in temporaries any stack entries that contain registers that 
   must be saved by the caller. *)

   VAR
      Sptr : Stackptr;
      TempAt: AddrToken;

   BEGIN
write('[savestack');
   Sptr := Tos;
   WHILE (Sptr <> NIL) DO
      BEGIN
write(':',Sptr^.At.Form);
      WITH Sptr^ DO
         IF At.Form <> Smst THEN
            IF (At.Reg IN Callersaveregs) OR
               (At.Reg2 IN Callersaveregs) THEN
                  BEGIN
                  MaktempAt (TempAt, At.Mdtype, At.Size, Reference);
   	          Moveit (TempAt, At);
	          At := TempAt;
                  END;
      Sptr := Sptr^.Snext;
      END;
write(']');
   END;

(* Recycletemp Gettemp Expandtemp *)

FUNCTION Recycletemp {(Size: Integer): Tempptr};
  (* Attempts to find a returned temporary block with exact
     size, and returns either a pointer to a found block or Nil. *)

VAR
        Found: BOOLEAN;
        Ptr: Tempptr;
   
    BEGIN
    Found := FALSE;
    Ptr := Firsttemp;
    WHILE (Not Found) AND (Ptr <> NIL) DO
        WITH Ptr^ DO
            BEGIN
            IF (Tmpsize = Size) AND (Refcount = 0) THEN
                BEGIN
                Found := TRUE;
		IF Ttemps THEN
                   Ugenmsg ('Recycling used temp.          ',Ptr^.Tmpoffset)
                END
             ELSE
                Ptr := Ptr^.Next
             END;
    IF Found 
    THEN Recycletemp := Ptr
    ELSE Recycletemp := NIL
    END;


PROCEDURE Gettemp {(VAR Tptr: Tempptr; Size: Integer; VAR Tlb: Integer)};

  (* Returns in Tlb the Offset in the temporary area
     of an available block of size Size.  The routine first attempts
     to find a block of temporary space that has already been used but
     is now free and is exactly the right size.  Failing that, it
     increases the size of the temporary area *)
        
   VAR
        Ntemp:  Tempptr;

   BEGIN
    (* First see if a suitable temporary block exists in the returned temp 
       list*)
write('[Gettemp:Size:',Size:1);
    Ntemp := RecycleTemp(Size);
    IF Ntemp = NIL 
    THEN
        BEGIN   (* No suitable temp found, increase size of temp area *)
        NEW(Ntemp);
        WITH Ntemp^ DO
            BEGIN
            Next := NIL;
            Tmpsize := SIZE;
            Tmpoffset := Maxtmp;
            Maxtmp := Maxtmp + Size;
	    IF Ttemps THEN
               Ugenmsg ('Adding new temp to temp list. ',Tmpoffset)
            END;
        IF Lasttemp = NIL THEN
            BEGIN
            Firsttemp := Ntemp;
            Lasttemp  := Ntemp
            END
        ELSE
            BEGIN
            Lasttemp^.next := Ntemp;
            Lasttemp := Ntemp
            END
        END;
    Ntemp^.Refcount := 1;
    Tptr := Ntemp;
    Tlb := Ntemp^.Tmpoffset;
write(' tlb:',tlb:1,']');
   END;


FUNCTION Expandtemp {(VAR At: Addrtoken; NewSize: Integer): Boolean};

   (* This routine is called by UADJ to expand the size of a temporary.
      This is only possible if it is the last temporary in the temporary
      area. *)

   BEGIN
write('Expandtemp(to:',newsize:1,')');
   IF At.Tmpptr <> Lasttemp THEN
      Expandtemp := False
   ELSE WITH Lasttemp^ DO
      BEGIN 
      Expandtemp := True;
      IF Newsize < Tmpsize THEN
         Ugenerror ('Error in ExpandTemp           ', Tmpsize)
      ELSE
         Maxtmp := Maxtmp + Newsize - Tmpsize;
      Tmpsize := Newsize;
      At.Size := Newsize;
      END;
   END

(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

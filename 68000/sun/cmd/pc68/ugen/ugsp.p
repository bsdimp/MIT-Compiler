(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%iff UnixPascal*)
{  (*$M-*)}
{}
{  PROGRAM UGSP;}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Ug.Inc';}
{   INCLUDE 'Ugrg.Imp';}
{   INCLUDE 'Ugat.Imp';}
{   INCLUDE 'Ugcd.Imp';}
{   INCLUDE 'Ugst.Imp';}
{   INCLUDE 'Ugtm.Imp';}
(*%else*)
#include "ucode.h";
#include "ug.h";
#include "ugrg.h";
#include "ugat.h";
#include "ugcd.h";
#include "ugst.h";
#include "ugtm.h";
#include "ugsp.h";
(*%endc*)

(* This module contains all the schema primitives. *)

(*%setf Vectorops*)  (* use vector ops instead of loops? *)

CONST
   Display = '_display';
    Loopcutoff = 5;

VAR

   (* The following tables are used to map between Icode opcodes and Ocode
      opcodes. *)

   Simplemap: ARRAY[Icode] OF Ocode;
   (* Unary operations: *)
   Unopmap: ARRAY[Icode, Mdatatype] OF Ocode;
   (* Binary operations.  The datatype of the two operands must be the same.
      The last index indicates whether the instruction should be reversed,
      (e.g. reverse subtract instead of regular subtract) *)
   Binopmap: ARRAY [Icode, Mdatatype, Boolean] OF Ocode;
   (* Simple moving of data, PLUS transformation from one type to another
      (e.g. integer to real) *)
   Moveops: ARRAY [Mdatatype, Mdatatype] OF Ocode;
   (* Trap if out-of-bounds: *)
   Trapops: ARRAY [-2..2, Mdatatype] OF Ocode;
   (* Set if out-of-bounds: *)
   Chkops: ARRAY [-2..2, Mdatatype] OF Ocode;
   (* Boolean complements *)
   NotI: ARRAY [Xequ..Xnor] OF Icode;
   (* Reverse order of operands of tests. E.g.: Xlss->Xgrt *)
   ReverseTest: ARRAY [Xequ..Xneq] OF Icode;
   (* Compare and skip *)
(*   Skipops: ARRAY [Xequ..Xneq, Mdatatype] OF Ocode;*)
   (* Compare with zero and jump *)
(*   Jumpzops: ARRAY [Xequ..Xneq, Mdatatype] OF Ocode;*)
   (* Convert Xles to slt etc.*)
   SetCondop: ARRAY [Xfalse..Xneq] OF  Ocode;
   (* Convert Xles to jlt etc. *)
   JumpOp: ARRAY [Xequ..Xneq] OF Ocode;
   (* Convert i to 2**i = 1 leftshift i *)
   OneLeftShift: ARRAY [0..15] OF Integer;
   (* Return no. of AddrUnits taken by each MdataType *)
   SizeOf: ARRAY [MdataType] OF 0..8;

   Curpage, Curline, SaveRegOffset: Integer;

   (* frequently used address tokens: *)
   Sr0At,
   Entry1At,

   ZeroAt,
   NulAt,
   FpAt,
   SpAt,
   SpDecAt,	(* Emits sp@- *)
   CurprocAt: Addrtoken;

   Tfastcheck: Boolean; (* Trap instead of JSR on out-of-bounds *)
PROCEDURE Initsp{};

   VAR Ic: Icode;
       Oc,Oc2: Ocode;
       Md,Md2: Mdatatype;
       I: Integer;
   BEGIN
   Tfastcheck := True;
   Curpage := 1;
   Curline := 0;
   FOR Ic := Xabs TO Xmove DO
      BEGIN
      SimpleMap[Ic] := Pillegal;
      FOR Md := ILL TO M DO
         BEGIN
         Unopmap [Ic,Md] := Pillegal;
         Binopmap [Ic,Md,True] := Pillegal;
         Binopmap [Ic,Md,False] := Pillegal;
         END;
      END;
   FOR Md := ILL TO M DO
      FOR Md2 := ILL TO M DO
         Moveops[Md,Md2] := Pillegal;
         
   SimpleMap[Xand] := andl;
   SimpleMap[Xexch] := exg;
   SimpleMap[Xmove] := movl;
   SimpleMap[Xmovadr] := lea;
   SimpleMap[Xinc] := addql;
   SimpleMap[Xdec] := subql;
   SimpleMap[Xjumplab] := jra;
   SimpleMap[Xjump] := jmp;
   SimpleMap[Xret] := rts;
   SimpleMap[Xcup] := jsr;


   NotI[Xgeq] := Xles;
   NotI[Xles] := Xgeq;
   NotI[Xgrt] := Xleq;
   NotI[Xleq] := Xgrt;
   NotI[Xequ] := Xneq;
   NotI[Xneq] := Xequ;
   NotI[Xand] := Xnand;
   NotI[Xnand]:= Xand;
   NotI[Xor]  := Xnor;
   NotI[Xnor] := Xor;

   ReverseTest[Xgeq] := Xleq;
   ReverseTest[Xles] := Xgrt;
   ReverseTest[Xgrt] := Xles;
   ReverseTest[Xleq] := Xgeq;
   ReverseTest[Xequ] := Xequ;
   ReverseTest[Xneq] := Xneq;

   SetCondop[Xtrue]:= strue;
   SetCondop[Xfalse]:=sfalse;
   SetCondop[Xequ] := seq;
   SetCondop[Xgeq] := sge;
   SetCondop[Xgrt] := sgt;
   SetCondop[Xleq] := sle;
   SetCondop[Xles] := slt;
   SetCondop[Xneq] := sne;

   JumpOp[Xequ] := jeq;
   JumpOp[Xgeq] := jge;
   JumpOp[Xgrt] := jgt;
   JumpOp[Xleq] := jle;
   JumpOp[Xles] := jlt;
   JumpOp[Xneq] := jne;

   (* !!! The Movemany instructions are used to copy a data object from one
      place to another, and also to transform it from Real to Integer and
      vice-versa.  The Trans instruction is used when copying a signed
      number from one precision to another.  When copying a signed number
      to an unsigned, and vice-versa, MOV is always used.  It is up to
      the user/compiler to guarantee that the number moved is non-negative
      and will fit in the space given (for example, when storing in a 
      signed quarterword, the number to be stored must not be bigger than
      2**8-1 *)
   Oc := movb;
   (* unsigned -> signed *)
   FOR Md := Qu TO Hu DO
      FOR Md2 := Qs TO Ds DO
         BEGIN
         Moveops [Md,Md2] := Oc;
         Oc := Succ (Oc);
         END;
   (* signed -> unsigned *)
   FOR Md := Qs TO Ds DO
      BEGIN
      Moveops [Md,Qu] := Pillegal;
      Moveops [Md,Hu] := Pillegal;
      END;
   (* signed -> signed *)
   FOR Md := Qs TO Ds DO
      FOR Md2 := Qs TO Ds DO
         BEGIN
         Moveops [Md,Md2] := Pillegal;
         END;

   (* same precision *)
   Moveops [Qu,Qu] := movb;
   Moveops [Hu,Hu] := movw;
   Moveops [Qs,Qs] := movl;
   Moveops [Hs,Hs] := movw;
   Moveops [Ss,Ss] := movl;
   Moveops [Sa,Sa] := movl;
   Moveops [Sa,Ss] := movl; (* !!! *)
   Moveops [Ss,Sa] := movl;
   
   (* floating point -> floating point *)
   Moveops [Sf,Sf] := movl;

   (* pointer -> pointer *)
   Moveops [Sa,Sa] := movl;

   Unopmap [Xnot, Qu] := notb;
   Unopmap [Xnot, Qs] := notb;
   Unopmap [Xnot, Hu] := notw;
   Unopmap [Xnot, Hs] := notw;
   Unopmap [Xnot, Ss] := notl;

   Unopmap [Xneg, Ss] := negl;
   Unopmap [Xinc, Qs] := addqb;
   Unopmap [Xinc, Hs] := addqw;
   Unopmap [Xinc, Ss] := addql;
   Unopmap [Xdec, Qs] := subqb;
   Unopmap [Xdec, Hs] := subqw;
   Unopmap [Xdec, Ss] := subql;

   Binopmap [Xshift, Ss, False] := asll;
   Binopmap [Xdivmod, Ss, False] := divs;

   Binopmap [Xadd, Qs, False] := addb;
   Binopmap [Xadd, Hs, False] := addw;
   Binopmap [Xadd, Ss, False] := addl;
   
   Binopmap [Xsub, Qs, False] := subb;
   Binopmap [Xsub, Hs, False] := subw;
   Binopmap [Xsub, Ss, False] := subl;

   Binopmap [Xinc, Qs, False] := addqb;
   Binopmap [Xinc, Hs, False] := addqw;
   Binopmap [Xinc, Ss, False] := addql;
   
   Binopmap [Xdec, Qs, False] := subqb;
   Binopmap [Xdec, Hs, False] := subqw;
   Binopmap [Xdec, Ss, False] := subql;

   Binopmap [Xmpy, Hu, False] := mulu;
   Binopmap [Xmpy, Hs, False] := muls;
   Binopmap [Xmpy, Ss, False] := muls;

   Binopmap [Xand, Qs, False] := andb;
   Binopmap [Xand, Qu, False] := andb;
   Binopmap [Xand, Hs, False] := andw;
   Binopmap [Xand, Hu, False] := andw;
   Binopmap [Xand, Ss, False] := andl;

   Binopmap [Xor, Qs, False] := orb;
   Binopmap [Xor, Qu, False] := orb;
   Binopmap [Xor, Hs, False] := orw;
   Binopmap [Xor, Hu, False] := orw;
   Binopmap [Xor, Ss, False] := orl;

   Binopmap [Xxor, Qs, False] := eorb;
   Binopmap [Xxor, Qu, False] := eorb;
   Binopmap [Xxor, Hs, False] := eorw;
   Binopmap [Xxor, Hu, False] := eorw;
   Binopmap [Xxor, Ss, False] := eorl;
   Binopmap[Xadd, Ss, True ] := addl;
   Binopmap[Xadd, Ss, False] := addl;
   Binopmap[Xadd, Sa, True ] := addl;
   Binopmap[Xadd, Sa, False] := addl;
   Binopmap[Xsub, Ss, False] := subl;
   (*div,mod,mpy*)
   FOR Ic := Xabs TO Xmove DO
      IF Ic IN [Xadd,Xmpy,Xand,Xor,Xxor,Xequ,Xneq] THEN
         FOR Md := Qs TO M DO
            BEGIN
            Binopmap [Ic,Md,True] := Binopmap [Ic,Md,False];
            END;
   FOR Md := Qs TO Df DO
      BEGIN
      Binopmap[Xles, Md, True] := Binopmap[Xgrt, Md, False];
      Binopmap[Xgrt, Md, True] := Binopmap[Xles, Md, False];
      Binopmap[Xleq, Md, True] := Binopmap[Xgeq, Md, False];
      Binopmap[Xgeq, Md, True] := Binopmap[Xleq, Md, False];
      END;

   OneLeftShift[0] := 1;
   FOR I := 1 TO 15 DO OneLeftShift[i] := 2 * OneLeftShift[i - 1];

   SizeOf[ILL] := 0;	SizeOf[M] := 0;
   SizeOf[Qs] := 1;	SizeOf[Qu] := 1;
   SizeOf[Hs] := 2;	SizeOf[Hu] := 2;
   SizeOf[Ss] := 4;	SizeOf[Su] := 4;
   SizeOf[SA] := 4;
   SizeOf[Sf] := 4;	SizeOf[Df] := 8;

   MakRegAt (FpAt, Sa, Fp);
   MakRegAt (SpAt, Sa, Sp);
   MakRegAt (SpDecAt, Sa, Sp);
   SpDecAt.Form := RIDec;
   MakintconstAt (Zeroat, 0);
   MakregAt (NulAt, Ss, -1);
   NulAt.Form := Empty;
   Makaddrat (CurprocAt, Sa, 0, Blabl, Reference);
   MakintconstAt (Entry1At, 0);  Entry1At.Fixup := FNegFramesize;
END;

(* SetSpVar PowerofTwo AtPowerofTwo *)

PROCEDURE SetSpVar {(Varbl:SharedVar; Val: Integer)};
   BEGIN
   IF Varbl = ShFastcheck THEN
      Tfastcheck := Odd (Val) 
   ELSE IF Varbl = ShPage THEN
      Curpage := Val
   ELSE IF Varbl = ShLine THEN
      Curline := Val;
   END;

FUNCTION PowerofTwo {(Num: Integer;  VAR Exp: Integer): Boolean};

   (* IF Num is a power of two and Num >= 2, returns the exponent in EXP *)

   VAR I,J: Integer;

   BEGIN
   I := 2; J := 1;
   WHILE I < Num DO
      BEGIN I := I*2;  J := J+1; END;
   Poweroftwo := I=Num;
   Exp := J;
   END;

FUNCTION AtpowerofTwo {(VAR At: Addrtoken; VAR Shift: Integer): Boolean};
   (* Discovers whether At is an integer constant which is a power of two. *)

   BEGIN
   IF (At.Ctype <> Intconst) THEN
      AtpowerofTwo := False
   ELSE
      AtpowerofTwo := Poweroftwo (At.Displ, Shift);
   END;

FUNCTION AdjOcode (Base: Ocode; MType: MdataType): Ocode;
   (* Assuming Base is the 32-bit version of an instruction,
      return the corresponding instruction for MType.
      WARNING: If there is none, you'll get garbage. *)

   BEGIN
   CASE MType OF
      Qs,Qu: AdjOcode := Pred(Pred(Base));
      Hs,Hu: AdjOcode := Pred(Base);
      Ss,Su,Sa,Sf: AdjOcode := Base;
      Ds,Df,Ill,M:
         BEGIN
	 Ugenerror('Illegal data type to AdjOcode', Ord(MType));
	 AdjOcode := Pillegal;
	 END;
      END;
   END;

PROCEDURE Loadreg {(VAR At: Addrtoken)};

   (* Moves contents of At into a work register or register pair.
      Also transforms it so it is always a single or double word. *)

   VAR
       RegAt: Addrtoken;
       Rg: Register;

   BEGIN

write('[Loadreg: Type:',At.Mdtype,',Form:',At.Form,',Cntx:',At.Context,',Displ:',at.Displ:1);
write(' IsB:',IsBetween(At, -128, 127));
   Rg := Allocatereg (At.Mdtype);
   Makregat (RegAt, At.Mdtype, Rg);
   IF (At.Context = Literal) AND NOT (At.Form IN [K,L]) THEN
      IF (At.Form = RIR) AND (At.Displ = 0) AND (SoleUser(At.Reg)) THEN
         BEGIN
	 Clean (RegAt); RegAt := At;
	 MakregAt (At, Ss, RegAt.Reg2);
	 RegAt.Form := R; RegAt.Reg2 := -1; RegAt.Context := Reference;
         Emit2 (addl, RegAt, At);
	 END
      ELSE Emit2 (SimpleMap[Xmovadr], RegAt, At)
   ELSE IF IsBetween (At, -128, 127) THEN
      Emit2 (moveq, RegAt, At)
   ELSE
      Emit2 (AdjOcode(movl, At.Mdtype), RegAt, At);
(*      BEGIN
      IF At.Mdtype IN [QS, QU, HS, HU] THEN
	 BEGIN
	 RegAt.Mdtype := Ss;
	 Emit2 (Moveops[Ss, At.Mdtype], Regat, At);
	 END
      ELSE Emit2 (Moveops[At.Mdtype,At.Mdtype],Regat,At);
      END;
 *)
   Clean (At);
   At := RegAt;
write(']');
   END;

(* Getaddr Indirect Adjaddr Adjobject CollapseIndex Signedunpack *)

PROCEDURE GetAddr {(VAR At: Addrtoken)};

   (* Changes an address token to be the address of whatever it currently
      is. *)
   BEGIN
   IF At.Context <> Reference THEN
      UgenError ('Getting address of literal.   ',Ord(At.Form));
   At.Context := Literal;
   At.Mdtype := Sa;
   END;

PROCEDURE Indirect {(VAR At: Addrtoken; Newmdt: Mdatatype; Newlen: Integer)};

   (* Changes At to be the object it is currently pointing at.  It first
      tries to add the indirection by merely altering the address token.
      If it fails, it loads the address into a register and continues from
      there. *)
   BEGIN
write('[Indirect');
   IF NOT Collindirect (At) THEN
      BEGIN
      Loadreg (At);
      IF NOT Collindirect (At) THEN
         UgenError ('Can"t perform indirection.    ',Ord(At.Form));
      END;
   At.Mdtype := Newmdt;
   At.Size := Newlen;
write(']');
   END;

PROCEDURE Adjaddr {(VAR At: Addrtoken; Increment: Integer)};
   (* Increments (or decrements) an address by a fixed amount. *)

   BEGIN
   IF Increment <> 0 THEN
      IF NOT Colladjust (At, Increment) THEN
         BEGIN
	 Loadreg (At);
	 IF NOT Colladjust (At, Increment) THEN
	    UgenError ('Can"t adjust address.         ',Ord(At.Form));
	 END;
   END;

PROCEDURE Adjobject {(VAR At: Addrtoken; Increment: Integer;
		      NewMdtype: Mdatatype; Newlen: Integer)};
   (* On call, At represents a multi-word object or part of a multi-word
      object.  This adjusts At to represent another part of the object
      by adding Increment to the current address of At. *)
   BEGIN
   Getaddr (At);
   IF Increment <> 0 THEN
      IF NOT Colladjust (At, Increment) THEN
         BEGIN
	 Loadreg (At);
	 IF NOT Colladjust (At, Increment) THEN
	    UgenError ('Can"t adjust address.         ',Ord(At.Form));
	 END;
   Indirect (At, NewMdtype, Newlen);
   END;

PROCEDURE CollapseIndex {(VAR At1, At2: Addrtoken)};
   (* Creates token reprsenting At1[At2].  At1, At2 destroyed.  
      Result in At1. *)
   BEGIN
write('CollapseIndex[',At1.Form,'/',At1.Context,'/',At1.Displ);
   IF NOT ColadAddr (At1, At2) THEN
      BEGIN
      IF NOT Is68000 OR (At2.Form <> R) THEN Loadreg (At2);
      IF NOT ColadAddr (At1, At2) THEN
	 BEGIN
	 Loadreg (At1);
	 IF NOT ColadAddr (At1, At2) THEN
	    UgenError ('Can"t collapse address.       ',Ord(At2.Form));
	 END;
      END;
write('=>',At1.Form,'/R:',At1.Reg:1,'/R2:',At1.Reg2:1,'/D:',At1.Displ:1,']');
   END;

PROCEDURE SignedUnpack {(VAR At: Addrtoken)};
   (* Makes sure that At is not unsigned. *)
   VAR TmpAt: Addrtoken;
   BEGIN
   IF At.Mdtype IN [QU, HU] THEN
      BEGIN
      TmpAt := NulAt; TmpAt.Mdtype := SS;
      Moveit (TmpAt, At);
      At := TmpAt;
      END;
   END;

PROCEDURE MakFramePointerAt {(VAR At: AddrToken; TgtLevel,Curlevel: Integer)};

   (* Creates an address token representing a pointer to
      the stack frame for lexical level Tgtlevel, where Tgtlevel < Curlevel. *)

   VAR 
       Treg: Register;

   BEGIN
   IF MatchReg (Sa, Mmt, -Tgtlevel, 0, Treg, True) THEN
      MakregAt (At, Sa, Treg)
   ELSE
      BEGIN
      MakAddrAt (At, Sa, APW*(Tgtlevel - 1), Display, Reference);
      (* For entry & exit code we don't want anything in a register *)
      IF Tgtlevel < Curlevel THEN
         BEGIN
         Loadreg (At);
         Bindreg (At.Reg, Mmt, -Tgtlevel, 0);
	 END;
      END
   END;

PROCEDURE MakblkoffsetAt {(VAR At: Addrtoken; VAR U: Bcrec;
                            Tgtlevel,CurLevel: Integer; Cntx: Contexts)};

(* This routine creates an Addrtoken corresponding to a U-code (Block,Offset)
   pair.  (Offset MUST be aligned on an addr unit).
   IF the memory type is M, this translates into DSPL(FP).
   (If the reference is to another stack frame, and some code must be
   generated to get at that stack frame, it is generated now.)
   If the memory type is S, it translates into an offset from some
   statically allocated area, either the global storage for the module
   or some common block.
   If Block = 0, then it is an imported variable,
   and we must look it up in StaticAreas[0] and reference it by name.  
   If the memory type is R, the correct register is found.
*)
   VAR Delta: Integer;
   BEGIN
   (* Construct an address token. *)
   At := NulAt;
   IF (U.Offset MOD Addrunit <> 0) THEN
      UgenError ('Offset not aligned.           ',U.Offset);
   WITH At DO
      BEGIN
      Context := Cntx;
      Mdtype := MachineType (U.Dtype, U.Length);
     (* Memory type S = static memory, e.g. an offset from a label. *)
        
      IF U.Mtype = Smt THEN  
	 BEGIN
	 Form := L;
	 IF U.I1 = 0 THEN
	    BEGIN
	    (* imported variable -- reference it by name *)
	    Findvar (U.Offset DIV AddrUnit, Labfield, Displ);
	    Extlab := True;
	    END
	 ELSE
	    BEGIN (* global static area or common area *)
	    GetAreaName (U.I1, Labfield);
	    Extlab := U.I1 > 1;  (* references to common areas are external *)
	    (* Check to see if this area has been declared via a DATA statement. *)
	    IF Labfield[1] = ' ' THEN
	       UgenError ('Missing DATA statement.       ',U.I1);
	    Displ := U.Offset DIV Addrunit;
	    END;
	 END

      (* Stack frame reference. *)
      ELSE IF (U.Mtype = Mmt) OR (U.Mtype = Pmt) THEN
	 BEGIN
	 IF U.Mtype = Mmt THEN Delta := Localstart
	 ELSE IF (At.Mdtype IN [Qs,Qu]) AND (U.Offset MOD WordSize = 0) THEN
	    Delta := 11
	 ELSE IF (At.Mdtype IN [Hs,Hu]) AND (U.Offset MOD WordSize = 0) THEN
	    Delta := 10
	 ELSE
	    Delta := 8;
	 IF Tgtlevel = Curlevel THEN
            MakrgoffAt (At, At.Mdtype, Fp, 
                          U.Offset DIV Addrunit + Delta, Fnone, Cntx)
	 ELSE 
	    BEGIN (* up-level reference *)
	    MakFramepointerAt (At, Tgtlevel, Curlevel);
	    Adjaddr (At, U.Offset DIV AddrUnit + Delta);
	    IF Cntx = Reference THEN
	       Indirect (At, MachineType (U.Dtype, U.Length),
	          U.Length DIV Addrunit);
	    END
	 END
      ELSE IF U.Mtype = Rmt THEN
	 BEGIN
	 Form := R;
         Reg := Regno (U.Offset);
	 END
      ELSE
	 UgenError ('Mblkoff/sp:Illegal memory type',ord(U.Mtype));
      Size := U.Length DIV Addrunit;
      END;
   END;

(* Moveblock Zeroblock Oneblock Moveit Convert *)

PROCEDURE Moveblock {(VAR Dest, Source: AddrToken; Len: Integer; IsAddress: Boolean)};

   (* Does a block move.  Dest and Source are the objects (not their
      addresses.  They are not altered.
      Can also set a block to a constant
      if Source.Form = K and Source.Context = Reference *)

   VAR
      LoopLab: Labl;
      SAt, DAt, LenAt, IndexAt, LoopAt: AddrToken;
   BEGIN
   CopyAt (SAt, Source); CopyAt (DAt, Dest);
   IF NOT IsAddress THEN
      BEGIN
      DAt.Mdtype := Sa; DAt.Context := Literal;
      IF SAt.Mdtype = M THEN
         BEGIN SAt.Mdtype := Sa; SAt.Context := Literal; END;
      END;
   Loadreg (DAt); DAt.Form := RIInc;
   Loadreg (SAt);
   IF SAt.Mdtype = Sa THEN SAt.Form := RIInc;
   IF Len < 9*APW THEN
      WHILE Len >= 4 DO
         BEGIN
	 Emit2 (movl, DAt, SAt);
	 Len := Len - 4;
	 END
   ELSE
      BEGIN
      MakintconstAt (LenAt, Len div APW - 1);
      MakregAt (IndexAt, Ss, Allocatereg(Ss));
      Emit2 (movl, IndexAt, LenAt);
      Createlabel (LoopLab);
      Emitlab (LoopLab);
      Emit2 (movl, DAt, SAt);
      MakAddrAt (LoopAt, Sa, 0, LoopLab, Reference);
      Emit2 (dbf, LoopAt, IndexAt);
      Len := Len mod APW;
      Clean (IndexAt);
      END;
   IF Len >= 2 THEN Emit2 (movw, DAt, SAt);
   IF Len >= 1 THEN Emit2 (movb, DAt, SAt);
   Clean (SAt); Clean (DAt);
   END;

PROCEDURE Movevblock {(Dest, Source, Size: AddrToken)};

   (* Does a block move of a block whose size is known only at runtime. *)
   VAR
       Wordaligned: Boolean;
   BEGIN
   UgenError ('Movevblock not implemented.   ',Novalue);
   END;

PROCEDURE Zeroblock  {(Dest: AddrToken; Len: Integer)};

   (* Zeroes out a block at the address given.  DOES NOT affect the
      original addrtoken.  *)
   VAR TmpAt: Addrtoken;
   BEGIN
      TmpAt := ZeroAt;
      Moveblock (Dest, TmpAt, Len, False);
   END;

PROCEDURE Oneblock  {(Dest, Len: AddrToken)};

   (* Loads each word of a block with all ones.  Len is ONE GREATER THAN
      the length of the block, and may be = 1.  Note that it is
      an addresstoken, not an integer, because it isn't
      known until runtime.  Called only by UMUS. 
      Len is measured in set size unit, which is currently 32 bits.

              Dec (Len);  IF Len = 0 THEN Jump to out
              At1 := Addr(Dest);
        Loop: 
	      At1^ := -1
              Inc (At1); Dec (Len); IF Len > 0 Jump to Loop;
        Out:
	
      Dest, Len destroyed.
     *)

     Var TmpDest, OutlabAt, LooplabAt: Addrtoken;
         Looplab, Outlab: Labl;

   BEGIN
   (* load length of block into register *)
   IF NOT IsWorkReg (Len) THEN Loadreg (Len);
   MakintconstAt (TmpDest, 1);
   Emit2 (subql, Len, TmpDest);
   MakintconstAt (TmpDest, 2);
   Emit2 (lsll, Len, TmpDest);
   (* dec (len); if len = 0, jump to outlab *)
   (* Dest := addr(Dest); *)
   Getaddr (Dest);   Loadreg (Dest); Dest.Form := RIInc;
   Createlabel (Outlab);
   SimpleJump (Outlab);
   (* emit loop label *)
   Createlabel (Looplab);  Emitlab (Looplab);
   MakAddrAt (LooplabAt, Sa, 0, Looplab, Reference);
   (* Dest^ := -1; Increment Dest *)
   Emit1 (strue, Dest);
   Clean (Dest);
   Emitlab (Outlab);
   (* Decrement Len and jump to beginning *)
   Emit2 (dbf, LooplabAt, Len);  Clean (Len);
   END;

PROCEDURE Moveit {(VAR Dest, Source: AddrToken)};

   (* Moves a data object from one place to another. Source is Cleaned *)

   VAR TmpAt, At1, At2: AddrToken; SourceType: Mdatatype;
   BEGIN
   SourceType := Source.Mdtype;
write('[Moveit');
   IF IsWorkReg (Dest) THEN Killreg (Dest.Reg);
   IF Dest.Context = Literal THEN
      UgenError ('Moving to a literal address.  ',Novalue);
   IF (Source.Context = Literal)
   AND (Source.Form <> K) AND (Source.Form <> L) THEN
      BEGIN
      IF Dest = SpDecAt THEN
	 Emit1 (pea, Source)
      ELSE
	 BEGIN
	 IF Dest.Mdtype <> SA THEN
	    UgenError ('Moving address to non-address.',Novalue);
         Loadreg (Source);
         Emit2 (SimpleMap[Xmove], Dest, Source);
	 END;
      Clean (Source);
      END
   ELSE IF Dest.Mdtype = M THEN
      Moveblock (Dest, Source, Dest.Size, False)
   ELSE
      BEGIN
      (* coerce integer constants to the form of the destination At *)
      IF (Source.Ctype = Intconst) AND 
         (Dest.Mdtype IN [Qu, Qs, Hu, Hs]) THEN
	    SourceType := Dest.Mdtype;
      TmpAt := Source;

      IF (SourceType = Sf) AND (Dest.Mdtype IN [Df,Ss,Su,Hs,Hu,Qs,Qu]) THEN
         BEGIN
	 IF (Dest.Form <> RIDec) AND (Dest.Mdtype = Df) THEN
	    BEGIN
	    Emit2 (movl, Dest, TmpAt);
	    Clean (TmpAt);
	    At2 := Dest;
	    AdjObject (At2, APW, Sf, APW);
	    Emit1 (clrl, At2);
	    TmpAt := Dest;
	    END
	 ELSE
	    BEGIN
	    IF Dest.Mdtype = Df THEN At2 := Dest ELSE At2 := SpDecAt;
	    Emit1 (clrl, At2);
	    Emit2 (movl, At2, TmpAt);
	    Clean (TmpAt);
	    TmpAt := At2;
	    END;
	 SourceType := Df;
	 END;
      IF (SourceType = Df) AND (Dest.Mdtype IN [Qs,Qu,Hs,Hu,Ss,Su]) THEN
         BEGIN
	 IF TmpAt <> SpDecAt THEN Moveit (SpDecAt, TmpAt);
	 MakAddrAt (At2, Sa, 0, 'fix     X', reference);
	 Callproc (2, false, 0, At2);
	 SourceType := Ss; (* Or sometimes Su ? *)
	 TmpAt.Mdtype:= SourceType;
	 Retrnfromcall (0, TmpAt);
	 END;
      IF (Dest.Mdtype IN [Hs,Ss,Sf,Df]) AND
         (SourceType IN [Qs,Hs]) AND (SourceType <> Dest.Mdtype) THEN
         BEGIN
	 IF NOT (TmpAt.Form IN [K,R]) THEN
	    BEGIN
	    IF IsWorkReg (Dest) THEN
	       At2 := Dest
	    ELSE MakregAt (At2, Qs, Allocatereg (Ss));	   
	    Emit2 (AdjOcode(movl,SourceType), At2, TmpAt);
	    Clean (TmpAt);
	    TmpAt := At2;
	    END;
	 IF SourceType = Qs THEN
	    BEGIN Emit1 (extw, TmpAt); SourceType := Hs; END;
	 IF Dest.Mdtype <> Hs THEN
	    BEGIN Emit1 (extl, TmpAt); SourceType := Ss; END;
	 END;
      IF (SourceType IN [Qu,Hu]) 
       AND (SizeOf[Dest.Mdtype] > SizeOf[SourceType]) THEN
         BEGIN
	 IF IsWorkReg(Dest) THEN At2 := Dest
	 ELSE
	    MakRegAt (At2, At2.Mdtype, AllocateReg(Ss));
	 Emit2 (moveq, At2, ZeroAt);
	 Emit2 (AdjOcode(movl, SourceType), At2, TmpAt);
	 Clean (TmpAt);
	 TmpAt := At2;
	 IF Dest.Mdtype IN [Sf,Df] THEN SourceType := Ss
	 ELSE SourceType := Dest.Mdtype;
	 TmpAt.Mdtype := SourceType;
	 END;
      IF (SourceType IN [Ss,Su]) AND (Dest.Mdtype IN [Qs,Qu,Hs,Hu]) THEN
	 BEGIN
	 IF NOT (TmpAt.Form IN [K,R]) THEN
	    AdjObject (TmpAt, SizeOf[Ss] - SizeOf[TmpAt.Mdtype],
	       Dest.Mdtype, SizeOf[Dest.Mdtype]);
	 SourceType := Dest.Mdtype;
	 END;
      IF (SourceType IN [Ss,Su]) AND (Dest.Mdtype IN [Sf,Df]) THEN
	 BEGIN
	 Moveit (SpDecAt, TmpAt);
	 MakAddrAt (At2, Sa, 0, 'float   X', reference);
	 Callproc (1, false, 0, At2);
	 SourceType := Df; TmpAt.Mdtype:= SourceType;
	 Retrnfromcall (0, TmpAt);
         END;
      IF (SourceType = Df) AND (Dest.Mdtype = Sf) THEN
         IF TmpAt.Form = R THEN
	    BEGIN
	    TmpAt.Mdtype := Ds; (* So that SplitAt will work *)
            SplitAt (TmpAt, At1, At2);
	    Clean (At2);
	    TmpAt := At1; SourceType := Sf; TmpAt.Mdtype := Sf;
	    END
	 ELSE TmpAt.Mdtype := Sf;
      IF TmpAt <> Dest THEN      
         IF Dest.Form = Empty THEN Dest := TmpAt
	 ELSE
            BEGIN
            Emit2 (AdjOcode(movl, Dest.Mdtype), Dest, TmpAt);
            IF IsWorkReg (TmpAt) AND (Dest.Mtyp <> Zmt) THEN
               Bindreg (TmpAt.Reg, Dest.Mtyp, Dest.Bno, Dest.Offst);
            Clean (TmpAt);
	    END;
      END;
write(']');
   END;

(* Transferregs *)

(* These procedures save registers at the beginning of a
   procedure and restore them at the end. *)

PROCEDURE Transferregs {(Save: Boolean; Pregs: Regset)};
   (* Transfers registers to or from the register save area. 
      Since the number of registers is not known until the end of a 
      procedure, Insert is used to emit the saving instructions. *)

   VAR Rg: Register;
       Regsused: Regset;
       RgAt, SpAt: Addrtoken;
   BEGIN
   Calleeregs (Regsused);
   Regsused := Regsused - [0] - Pregs; (* Redundant ??? *)
   MakregAt (SpAt, Sa, SP);
   IF Save THEN SpAt.Form := RIDec ELSE SpAt.Form := RIInc;
   MakintconstAt (RgAt, 0);
   RgAt.Ctype := Hexconst;
   FOR Rg := 0 TO Maxreg DO
      IF Rg IN Regsused THEN
         IF Save THEN RgAt.Displ := RgAt.Displ + OneLeftShift[15 - Rg]
         ELSE RgAt.Displ := RgAt.Displ + OneLeftShift[Rg];
   IF RgAt.Displ > 0 THEN
      IF Save THEN
         Insert (moveml, SpAt, RgAt, SaveRegOffset)
      ELSE
         Emit2 (moveml, RgAt, SpAt);
   END;

PROCEDURE Moveregs {(Insert,Save: Boolean; Rgs: Regset; VAR Locat: AddrToken)};
   BEGIN
   Transferregs (Save, Rgs);
   END;

(* EmitEntrycode EmitExitcode Calldebugger *)

PROCEDURE EmitEntrycode {(Proclabl: Labl; Savedisplay: Boolean;
                         VAR Dbginfo: Dbginforec; Curlvl: Integer)};
   (* Emits all procedure entry code, except for register saves, which
      are patched in later. *)
   VAR At: AddrToken; I: Integer;
   BEGIN
   (* Push FP onto stack; increase SP by 3 + Framesize); *)
   Emit2 (link, Entry1At, FPAt);
   SaveRegOffset := 1;
   IF SaveDisplay THEN
      BEGIN
      MakFramePointerAt (At, Curlvl, Curlvl);
      CopyAt (At, At);
      Moveit (SpDecAt, At);	(* Push Display[Curlevel] *)
      Moveit (At, FpAt);
      SaveRegOffset := SaveRegOffset + 2; (* Since two extra instructions *)
      Clean (At);
      END;
   END;

PROCEDURE EmitExitcode {(Restoredisplay: Boolean; Curlvl: Integer; VAR Dbginfo:Dbginforec)};
   (* Emits return code.  Note that this may occur more than once per
      procedure.  Do not worry about restoring registers here. *)
   VAR At: AddrToken; I: Integer;
   BEGIN
   IF Restoredisplay THEN
      BEGIN
      MakFramePointerAt (At, Curlvl, Curlvl);
      SpDecAt.Form := RIInc; Moveit (At, SpDecAt); SpDecAt.Form := RIDec;
      Clean (At);
      END;
   (* Restore FP and CP and return. *)
   Emit1 (unlk, FPAt);
   Emit0 (SimpleMap [Xret]);
   END;

PROCEDURE RestoreRegs {(Rgs: Regset)};
   BEGIN
   Transferregs (False, Rgs);
   END;

PROCEDURE SaveRegs {(Rgs: Regset)};
   BEGIN
   Transferregs (True, Rgs);
   END;

PROCEDURE CallDebugger{};
   (* Emits code to jump to the debugger on entry to the main procedure. *)

   BEGIN
   END;

(* RestFrame ResetFrame *)

(* When a jump is made from a inner to procedure to an outer procedure,
   the stack must be cut back to correspond to the stack frame of the
   outer procedure.  This is done partly before the jump, at the GOOB,
   and partly after the jump, at the LAB.  This is because the nested 
   procedure can find the location of the frame in question, using
   display pointers, but not necessarily its size. *)

PROCEDURE Cutstack {(Tgtlevel, Curlevel: Integer)};

   (* Called by GOOB to generate code to return the stack frome to the
      state it should be after the jump.  Co-operates with  Resetframe. *)
   VAR TmpAt, LabAt: Addrtoken; LoopLab: Labl;
   BEGIN
   (* Load FP with old FP. *)
   IF Tgtlevel + 1 < Curlevel THEN
      BEGIN
      MakFramepointerAt (TmpAt, Tgtlevel+1, Curlevel);
      Moveit (FpAt, TmpAt);
      END;
   (* Load TmpAt with desired FP *)
   MakframepointerAt (TmpAt, Tgtlevel, Curlevel);
   (* WHILE FP <> desired FP do unlk *)
   CreateLabel (LoopLab);
   EmitLab (LoopLab);
   Emit1 (unlk, FpAt);
   Emit2 (cmpal, FpAt, TmpAt);
   MakAddrAt (LabAt, Sa, 0, LoopLab, Reference);
   Emit1 (jne, LabAt);
   Clean (TmpAt);
   END;

PROCEDURE RestFrame{};
   
   VAR TmpAt: Addrtoken;
   (* Called by Ulab when the label is
      jumped to by another procedure.  Emits code to
      restore SP by loading it with Framesize + contents of FP. FP and CP
      must have been restored before the jump is made. *)
   BEGIN
(*   TmpAt := Entry1At;
   TmpAt.Reg := FP;
   Emit2 (SimpleMap[Xmove], SpAt, TmpAt);
 *)
   END;


(* Savepassedprocdisplay Restrcalleedisplay Restorcallerdisplay *)

   (* When a procedure is passed as its parameter, its static environment at
      the time is is passed must be put into the procedure descriptor along
      with its address.   This is either its context pointer, or all the
      displays, starting with lexical level 2 and going up to (its level - 1).
   *)

PROCEDURE Savepassedprocdisplay {(VAR At: Addrtoken; Curlev, Passeelev: Integer)};

   (* Used to save the current display wwhen a procedure
      is passed.  At is the part of the procedure descriptor where the 
      display is to be saved. *)

   VAR TmpAt: Addrtoken;
       I: Integer;

   BEGIN
   IF NOT (At.Form IN [R,RIInc]) THEN (* Kludge !!! *)
       BEGIN
       IF At.Context = Reference THEN Getaddr(At);
       Loadreg(At);
       At.Form := RIInc
       END;
   (* At is assumed to have context Reference and Form RIInc *)
   MakIntconstAt (TmpAt, Passeelev - 2);
   Moveit (At, TmpAt);
   FOR I := 2 TO Passeelev - 1 DO
      IF I = Curlev THEN
         Moveit (At, FpAt)
      ELSE
         BEGIN
         MakframepointerAt (TmpAt, I, Curlev);
         Moveit (At, TmpAt);
	 END;
   END;
   
PROCEDURE Restrcalleedisplay {(VAR At: Addrtoken)};

   (*  Called when a procedure which has been passed as
       a parameter is invoked.  It restores the static environment of the
       callee, which it gets from the procedure descriptor, by exchanging
       it with the current display.  At is the part of the descriptor where
       the display is kept. *)

   VAR RegAt, CtrAt, ProcAt, DsplAt, LoopLabAt: AddrToken;
       LoopLab, LoopBotLab: Labl;

   BEGIN      
   (* Load number of fp's to be moved *)
   CopyAt (ProcAt, At);
   GetAddr (ProcAt); LoadReg (ProcAt);
   CopyAt (CtrAt, ProcAt);
   CtrAt.Form := RIInc; CtrAt.Mdtype := Ss;
   LoadReg (CtrAt);
   ProcAt.Form := RI;
   MakAddrAt (DsplAt, Sa, APW, Display, Literal);
   LoadReg (DsplAt); DsplAt.Form := RI;
   MakRegAt (RegAt, Sa, AllocateReg(Sa));
   CreateLabel (LoopBotLab);
   SimpleJump (LoopBotLab);
   (* Loop head *)
   CreateLabel (LoopLab);
   EmitLab (LoopLab);
   MakAddrAt (LoopLabAt, Sa, 0, LoopLab, Reference);
   (* Exchange and increment ProcAt and DsplAt *)
   Emit2 (movl, RegAt, DsplAt);
   DsplAt.Form := RIInc;
   Emit2 (movl, DsplAt, ProcAt);
   ProcAt.Form := RIInc;
   Emit2 (movl, ProcAt, RegAt);
   (* Loop tail *)
   EmitLab (LoopBotLab);
   Emit2 (dbf, LoopLabAt, CtrAt);
   Clean (CtrAt); Clean (DsplAt); Clean (ProcAt);
   END;

(* Pushparm MakFuncResAt Callproc Retrnfromproc *)

PROCEDURE Pushparm {(ParAt: Addrtoken; Parcount: Integer)};
   (* Puts next parameter on the stack (DownStkLnk only) *)
   BEGIN
   IF ParAt.Mdtype IN [Qs,Hs] THEN SpDecAt.Mdtype:= Ss
   ELSE IF ParAt.Mdtype IN [Qu,Hu] THEN SpDecAt.Mdtype:= Su
   ELSE SpDecAt.Mdtype:= ParAt.Mdtype;
   Moveit (SpDecAt, ParAt);
   SpDecAt.Mdtype:= Ss;
   END;

PROCEDURE MakFuncResAt {(VAR FuncresAt: AddrToken)};
   (* Makes an AT representing the the function result at the time it is
      loaded by the callee just before the return. The Mdtype is passed
      in FuncresAt. *)
   BEGIN
   Grabreg (Funcresreg);
   MakRegAt (FuncresAt, FuncresAt.Mdtype, Funcresreg);
   END;

PROCEDURE Callproc {(Parcount: Integer; Uplevel: Boolean; Globaloffset: Integer;
                    Proc: Addrtoken)};

   (* Emits code to call a procedure.  Parcount is the number of parameters that
      have been pushed.  Uplevel is true if the call is to a procedure that is
      nested inside the current procedure. Globaloffset is the size of the extra
      partial stack frames that may have been pushed due to a nested function
      call. *)

   VAR TmpAt: Addrtoken;

   BEGIN
   IF (Globaloffset > 0) AND NOT Is68000 THEN
      BEGIN
      MakrgoffAt (TmpAt, Sa, Sp, Globaloffset, Fnone, Literal);
      Moveit (SpAt, TmpAt);
      END;
(*   IF Uplevel THEN
      Emit2 (SimpleMap[XCup], FpAt, Proc)
   ELSE
*)
   Savestack;
   Emit1 (SimpleMap[XCup], Proc);
   IF Parcount > 0 THEN
      BEGIN
      MakintconstAt (TmpAt, Parcount*APW);
      If Parcount > 2 THEN Emit2 (addl, SpAt, TmpAt)
      ELSE Emit2 (addql, SpAt, TmpAt);
      END;
   END;

PROCEDURE Retrnfromcall {(Globaloffset: Integer; VAR Funcres: Addrtoken)};

   (* Emits any code that is necessary after return from a call.  Also
      creates an At representing the Function result. The Mdtype of the
      function result is passed in Funcres. *)

   VAR TmpAt: Addrtoken;

   BEGIN
   IF (Funcres.Mdtype <> Ill) THEN
      BEGIN
      MakregAt (Funcres, Funcres.Mdtype, Funcresreg);
      (* If the function result register is already in use, then move
	 the function result to another work register. *)
(*      IF (Funcresreg IN Rgs) THEN
	 Loadreg (Funcres); Maybe: also d1 *)
      IF Funcres.Mdtype IN [Ds,Df] THEN Grabpair (Funcresreg)
      ELSE Grabreg (Funcresreg);
      END;
   IF Globaloffset > 0 THEN
      BEGIN
      MakrgoffAt (TmpAt, Sa, Sp, -Globaloffset, Fnone, Literal);
      Moveit (SpAt, TmpAt);
      END;
   END;

PROCEDURE Emitbinaryop {(Op: Icode; VAR TgtAt, At1, At2: Addrtoken)};

   (* Emits code to perform "TgtAt := At1 OP At2".
      If TgtAt is null, then it allocates a work register or pair
      in which put the result.

      At1 and At2 are cleaned.

      If we have a valid TgtAt, we can only store directly into it
      if the destination is the same precision as the two operands.
      E.g., "R.I  Min (RTA, J)" will not work if I is a signed quarterword. 

      Xdivmod is a special case, since the two operands are one word, but the
      result is two words. NOTE: Don't use Divmod for 68000.
      Currently, only intended for add,sub,and,or,xor
      xor will need fixing !!!
   *)

   VAR
      Treg: Register;
      TmpAt: Addrtoken;
      Precleaned: Boolean;
      Tlab: Labl; ParLen: Integer;
 
   BEGIN
write('Emitbin(',Op, ',(',TgtAt.Form,'/',TgtAt.Mdtype,'),(',At1.Form,'/',At1.Mdtype,'),(',At2.Form,'/',At2.Mdtype,')');
   IF Op = Xandcmp THEN (* Used for set difference *)
       BEGIN
       Loadreg (At2);
       Emit1 (AdjOcode(notl,At2.Mdtype), At2);
       Op := Xand;
       END;
   CoerceMtypes (At1, At2);  (* If either is a constant, convert it to the
    			        type of the other. *)
   IF Op IN [Xadd,Xsub] THEN IF IsBetween(At2, 1, 8) THEN
      IF Op = Xadd THEN Op := Xinc ELSE OP := Xdec;      
   IF (Op IN [Xmpy,Xdiv,Xmod]) OR (At1.Mdtype IN [Sf,Df]) THEN
      BEGIN (* Emit apropriate procedure call *)
      MakregAt (TmpAt, Ss, Sp); TmpAt.Form := RIDec;
      IF At1.Mdtype IN [Sf,Df] THEN
         BEGIN
	 TmpAt.Mdtype := Df;
	 ParLen := 4;
         CASE Op OF
	   Xadd: Tlab := 'fadd    X';
	   Xsub: Tlab := 'fsub    X';
	   Xmpy: Tlab := 'fmul    X';
	   Xdiv: Tlab := 'fdiv    X';
	   END;
         END
      ELSE
         BEGIN
	 ParLen := 2;
         CASE Op OF
            Xmpy: Tlab := 'lmul    X';
	    Xdiv: Tlab := 'ldiv    X';
	    Xmod: Tlab := 'lrem    X';
            END;
	 END;
      Moveit (TmpAt, At2);
      Moveit (TmpAt, At1);
      MakaddrAt (TmpAt, Sa, 0, Tlab, reference);
      CallProc (ParLen, False, 0, TmpAt);
      TmpAt.Mdtype:= At1.Mdtype;
      Retrnfromcall (0, TmpAt);
      IF TgtAt.Form = Empty THEN TgtAt := TmpAt
      ELSE Moveit (TgtAt, TmpAt);
      END
   (* if one of the operands is the same as the destination, we can use
      the form "1  1 OP 2" *)
   ELSE IF EquAt (At1,TgtAt) THEN 
      BEGIN
      IF (NOT IsWorkReg(At2)) AND (At2.Form <> K) AND
	 ((Op = Xxor) OR NOT ISWorkReg(TgtAt))
         THEN LoadReg (At2);
      IF IsWorkReg (At1) THEN Killreg (At1.Reg);
      Emit2 (BinopMap[Op, At1.Mdtype, False], At1, At2);
      Clean (At1); Clean (At2);
      END
   ELSE IF (EquAt (At2,TgtAt)) THEN 
      BEGIN
      IF (NOT IsWorkReg(At1)) AND (At2.Form <> K) AND
         ((Op = Xxor) OR NOT ISWorkReg(TgtAt))
         THEN LoadReg (At1);
      IF IsWorkReg (At2) THEN Killreg (At2.Reg);
      Emit2 (BinopMap[Op, At2.Mdtype, False], At2, At1);
      IF Op = Xsub THEN Emit1 (AdjOcode(negl,At2.Mdtype) ,TgtAt); (* Sometimes non-optimal ??? *)
      Clean (At1); Clean (At2);
      END
   (* Try the pattern "1  1 OP 2", where 1 or 2 is a work reg *)
   ELSE IF Isworkreg (At1) AND SoleUser(At1.Reg) THEN
      BEGIN
      Emit2 (BinopMap[Op, At1.Mdtype, False], At1, At2);
      Killreg (At1.Reg);
      Clean (At2);
      IF TgtAt.Form = Empty THEN TgtAt := At1
      ELSE Moveit (TgtAt, At1);
      END
   ELSE IF Isworkreg (At2) AND SoleUser(At2.Reg) AND (Op <> Xdivmod) THEN
      BEGIN
      Killreg (At2.Reg);
      Emit2 (BinopMap[Op, At1.Mdtype, False], At2, At1);
      IF Op = Xsub THEN Emit1 (AdjOcode(negl, At2.Mdtype), At2);
      Clean (At1);
      IF TgtAt.Form = Empty THEN TgtAt := At2
      ELSE Moveit (TgtAt, At2);
      END
   (* emit "R := 1; R := R OP 2" *)
   ELSE
      BEGIN
      Treg := -1;
(*      IF Op = Xdivmod THEN 
         At1.Mdtype := Ds; *)
      (* have to move one into a work register *)
      Loadreg (At1);
      Emit2 (BinopMap[Op, At2.Mdtype, False], At1, At2);
      IF TgtAt.Form = Empty THEN
	 TgtAt := At1
      ELSE
	 Moveit (TgtAt, At1);
      Clean (At2);
      END;
write(')');
    END; (* Emit binary op *)

PROCEDURE Negate (VAR V: Valu); (* Negate real constant <> 0.0 *)
   VAR I: Integer;
   BEGIN
   IF V.Chars[1] = '-' THEN V.Chars[1] := '+'
   ELSE IF V.Chars[1] = '+' THEN V.Chars[1] := '-'
   ELSE
      BEGIN
      FOR I:= V.Len DOWNTO 1 DO V.Chars[I+1] := V.Chars[I];
      V.Chars[1] := '-'; V.Len := V.Len + 1;
      END;
   END;

PROCEDURE Emitunaryop {(Op: Icode; VAR TgtAt, At1: Addrtoken)};

   VAR 
      Treg: Register; Tlab: Labl; TmpAt, At2: AddrToken;

   (* Emits code to perform "TgtAt := OP At1" *)

   BEGIN
 write('Emitunary<',Op,',(',TgtAt.Form,'/',TgtAt.Mdtype,'),(',At1.Form,'/',At1.Mdtype,')');
   TmpAt := At1;
   IF Op = Xrnd THEN
      BEGIN
      MakregAt (TmpAt, At1.Mdtype, Sp); TmpAt.Form := RIDec;
      Moveit (TmpAt, At1);
      MakAddrAt (At2, Sa, 0, 'round   X', reference);
      Callproc (2, false, 0, At2);
      TmpAt.Mdtype:= Ss;
      Retrnfromcall (0, TmpAt);
      END
   ELSE IF (TmpAt.Form <> R) OR NOT SoleUser (TmpAt.Reg) THEN
      IF (Op = Xneg) AND (TmpAt.Mdtype IN [Sf,Df]) AND (TmpAt.Form = K) THEN
         BEGIN END
      ELSE IF (TgtAt.Form = R) OR (TgtAt.Mdtype = Df) THEN
         BEGIN Moveit (TgtAt, TmpAt); TmpAt := TgtAt END
      ELSE Loadreg (TmpAt);
   IF Op = Xrnd THEN BEGIN END
   ELSE IF TmpAt.Mdtype IN [Sf,Df] THEN
      BEGIN
      MakintconstAt (At2, 31); (* Should work even if At1 not a register *)
      CASE Op OF
         Xabs: Emit2 (bclrl, TmpAt, At2);
	 Xneg:
	    IF TmpAt.Form <> K THEN
	       BEGIN
	       CreateLabel (Tlab);
	       CopyAt (TmpAt, TmpAt);
	       Compare (Xequ, NulAt, TmpAt, ZeroAt, Tlab);
	       Emit2 (bchgl, TmpAt, At2);
	       Emitlab (Tlab);
	       END
	    ELSE IF NOT Iszero (TmpAt) THEN Negate (TmpAt.Cstring);
	 END;
      END
   ELSE
      BEGIN
      IF IsWorkReg (TmpAt) THEN Killreg (TmpAt.Reg);
      Emit1 (Unopmap[Op,TmpAt.Mdtype], TmpAt);
      END;
   IF TgtAt.Form = Empty THEN TgtAt := TmpAt
   ELSE Moveit (TgtAt, TmpAt);
write('>');
   END;
   
PROCEDURE Inlinbnvectorop (Op: Icode; VAR TgtAt, At1, At2: Addrtoken; 
		  	    Units, Unitsize: Integer; Unittype: Mdatatype);
    VAR TmpTgtAt, Tat1, Tat2, Ttgt: Addrtoken;
        I: Integer;

    BEGIN
    Copyat (TmpTgtAt, TgtAt);
    At1.Mdtype := Unittype; At2.Mdtype := Unittype; TmpTgtAt.Mdtype := Unittype;
    FOR I := 1 to Units DO
       BEGIN
       CopyAt (Tat1,At1); CopyAt (Tat2,At2); CopyAt (Ttgt, TmpTgtAt);
       EmitBinaryOp (Op, Ttgt, Tat1, Tat2);
       Clean (Ttgt);
       AdjObject (At1, Unitsize, Unittype, Unitsize);
       AdjObject (At2, Unitsize, Unittype, Unitsize);
       AdjObject (TmpTgtAt, Unitsize, Unittype, Unitsize);
       END;
    Clean (At1); Clean (At2); Clean (TmpTgtAt);
    END;

PROCEDURE Loopbnvectorop (Op: Icode; VAR Tgtat, At1, At2: AddrToken;
    	  	          Units, Unitsize: Integer; Unittype: Mdatatype);

     (* Emits a loop binary op:

        Sizeat := Units;
        At1 := Addr(At1); At2 := Addr(At2); 
        Loop: TgtAt^ := At1^ OP At2^ 
              Inc (At1); Inc (At2); Inc (TgtAt); Dec (SizeAt); 
	      IF SizeAt > 0 goto Loop;

        Tgtat preserved, At1, At2 destroyed;
      *)

     Var TmpAt, SizeAt, LooplabAt: Addrtoken;
         Looplab: Labl;

   BEGIN
   CopyAt (TmpAt, TgtAt);
   MakIntconstAt (Sizeat, Units - 1);
   Loadreg (SizeAt);
   Getaddr (At1);   Getaddr (At2);   Getaddr (TmpAt);
   IF TmpAt = At1 THEN
      BEGIN Loadreg(At1); Loadreg(At2); Clean(TmpAt); CopyAt(TmpAt,At1) END
   ELSE IF TmpAt = At2 THEN
      BEGIN Loadreg(At1); Loadreg(At2); Clean(TmpAt); CopyAt(TmpAt,At2) END
   ELSE
      BEGIN Loadreg (At1);   Loadreg (At2);   Loadreg (TmpAt); END;
   At1.Form := RIInc; At1.Mdtype := Unittype;
   At2.Form := RIInc; At2.Mdtype := Unittype;
   TmpAt.Form := RIInc; TmpAt.Mdtype := Unittype;
   Createlabel (Looplab);
   Emitlab (Looplab);
   MakAddrAt (LooplabAt, Sa, 0, Looplab, Reference);
   Emitbinaryop (Op, TmpAt, At1, At2);
   Clean (TmpAt);
   Emit2 (dbf, LooplabAt, SizeAt);
   Clean (SizeAt);
   END;

PROCEDURE EmitbnvectorOp {(Op: Icode; VAR TgtAt, At1, At2: Addrtoken)};

   (* Emits code to do a binary operation on a vector.
      It is used mostly for operations on sets. *)

   VAR SizeAt: Addrtoken;
       Units, Unitsize: Integer;
       Unittype: Mdatatype;

   BEGIN
   IF (TgtAt.Form = Empty) THEN
      IF Istemp (At1) THEN
         CopyAt (TgtAt, At1)
      ELSE IF Istemp (At2) THEN
         CopyAt (TgtAt, At2)
      ELSE
         MaktempAt (TgtAt, M, At1.Size, Reference);
   Units := At1.Size DIV APW;
   Unittype := SS; Unitsize := APW;
   IF Units <= Loopcutoff THEN
      Inlinbnvectorop (Op, TgtAt, At1, At2, Units, Unitsize, Unittype)
   ELSE
      Loopbnvectorop (Op, TgtAt, At1, At2, Units, Unitsize, Unittype);
   END;

PROCEDURE Jumpifoutofrange {(VAR At: Addrtoken; Lowbound, Highbound: Integer;
				Dest: Labl)};

   (* Jumps to Dest if At is < lowbound or > highbound. Preserves At. *)

   VAR At2, AtDest: Addrtoken;

   BEGIN
   MakAddrAt (AtDest, Sa, 0, Dest, Reference);
   IF At.Form = K THEN
      BEGIN
      IF At.Displ < Lowbound THEN Emit1 (jra, AtDest);
      END
   ELSE IF Lowbound = 0 THEN
      BEGIN Emit1 (tstl, At); Emit1 (jlt, AtDest); END
   ELSE IF Lowbound = 1 THEN
      BEGIN Emit1 (tstl, At); Emit1 (jle, AtDest); END
   ELSE
      BEGIN
      Makintconstat(At2, Lowbound);
      Emit2 (cmpl, At, At2);
      Emit1 (jlt, AtDest);
      END;
   IF At.Form <> K THEN
      BEGIN
      MakintconstAt(At2, Highbound);  (* high bound *)
      Emit2 (cmpl, At, At2);
      Emit1 (jgt, AtDest);
      END
   ELSE IF At.Displ > Highbound THEN Emit1 (jra, AtDest);
   END;

PROCEDURE SimpleJump {(Dest: Labl)};

   (* Emits a jump to a label. *)
   VAR TmpAt: Addrtoken;

   BEGIN
   MakAddrAt (TmpAt, Sa, 0, Dest, Reference);
   Emit1 (SimpleMap[Xjumplab], TmpAt);
   END;

PROCEDURE CaseJump {(Dest: Labl)};

   (* Like Simplejump, except that the label is part of a case table.
      All case jumps must be of the same size. *)

   VAR TmpAt: Addrtoken;

   BEGIN
   MakAddrAt (TmpAt, Sa, 0, Dest, Reference);
   Emit1 (bra, TmpAt);
   END;

PROCEDURE Jumpindirect {(Dest: Addrtoken)};

   (* Emits a jump to a calculated location (case statement). *)

   BEGIN
   Emit1 (SimpleMap[Xjump], Dest);
   END;

PROCEDURE CompareTail (Op: Icode; Signed: Boolean;
		VAR TgtAt: Addrtoken; Dest: Labl);

   (* Assumes condition codes have been already been set.
      Op and Signed indicates the relation we are interested in.
      IF Dest is not blank, then jumps to it if the comparison is true.
      Otherwise, moves the result of the comparison into TgtAt.
      TgtAt is still active at the end. *)

   VAR At3: Addrtoken;

   BEGIN
   IF (Dest[1] <> ' ') THEN
      BEGIN
      IF Op IN [Xand,Xor,Xxor,Xin] THEN Op := Xneq
      ELSE IF Op IN [Xnand,Xnor,Xnin] THEN Op := Xequ;
      MakAddrAt (At3, Sa, 0, Dest, Reference);
      IF Signed THEN
	 Emit1 (JumpOp [Op], At3)
      ELSE
	 CASE Op OF
	    Xequ: Emit1 (jeq, At3);
	    Xgeq: Emit1 (jcc, At3);
	    Xgrt: Emit1 (jhi, At3);
	    Xleq: Emit1 (jls, At3);
	    Xles: Emit1 (jcs, At3);
            Xneq: Emit1 (jne, At3);
	    END;
      END
   ELSE IF Op IN [Xnand,Xnor] THEN Emitunaryop (Xnot, TgtAt, TgtAt) (* Redundant??? *)
   ELSE IF NOT (Op IN [Xand,Xor,Xxor]) THEN
      BEGIN
      IF TgtAt.Form = Empty THEN MakregAt (TgtAt, Qs, Allocatereg (Qs));
      IF Signed OR (Op IN [Xtrue,Xfalse,Xequ,Xneq]) THEN
         Emit1 (SetCondop[op], TgtAt)
      ELSE
         CASE Op OF
	    Xgeq: Emit1 (scc, TgtAt);
	    Xgrt: Emit1 (shi, TgtAt);
	    Xleq: Emit1 (sls, TgtAt);
	    Xles: Emit1 (scs, TgtAt);
	 END;
      IF (Op >= Xtrue) AND (Op <= Xneq) THEN
         Tgtat.Mdtype := Qs;
      END;
   END;

PROCEDURE Compare {(Op: Icode; VAR TgtAt, At1, At2: Addrtoken; Dest: Labl)};

   (* Compares At1 and At2, destroying them in the process.  IF Dest is
      not blank, then jumps to it if the comparison is true.  Otherwise,
      moves the result of the comparison into TgtAt.  TgtAt is still active
      at the end. *)

   VAR AtL,AtR,TmpAt: Addrtoken; TmpOp: Icode;

   BEGIN
   AtL := At1; AtR := At2;
   write('Compare(',Op,',', Dest);
   IF NOT (Op IN [Xin,Xnin,Xand,Xor,Xxor,Xnand,Xnor]) AND NOT Iszero (At2)
    AND ((At1.Form = K) OR ((At2.Form = R) AND (At1.Form <> R)))
    THEN (* Swap operands *)
      BEGIN AtL := At2; AtR := At1; Op:= ReverseTest[Op] END;
   IF Op IN [Xand,Xor,Xxor,Xnand,Xnor] THEN
      BEGIN (* Note we should avoid trashing TgtAt if a jump *)
      IF Op IN [Xnand,Xnor] THEN TmpOp := NotI[Op] ELSE TmpOp:= Op;
      TmpAt := TgtAt;
      Emitbinaryop (TmpOp, TmpAt, AtL, AtR);
      IF Dest[1] = ' ' THEN
         BEGIN
         IF Op IN [Xnand,Xnor] THEN
            BEGIN Emitunaryop (Xnot, TmpAt, TmpAt); Op := TmpOp END;
         TgtAt := TmpAt;
	 END
      ELSE Clean (TmpAt);
      END
   ELSE IF Op IN [Xin, Xnin] THEN
      BEGIN
      IF NOT (AtR.Form IN [R,K]) THEN Loadreg (AtR);
      IF AtL.Form = K THEN Loadreg (AtL);
      IF AtL.Form = R THEN Emit2 (btstl, AtL, AtR)
      ELSE Emit2 (btstb, AtL, AtR);
      IF Op = Xin THEN Op := Xneq ELSE Op := Xequ;
      END
   (* check for compare with zero *)
   ELSE IF Iszero (AtR) THEN
      BEGIN
      IF AtL.Form = K THEN Loadreg (AtL); (* Should be caught by optimizer *)
      Emit1 (AdjOcode(tstl, AtL.Mdtype), AtL);
      END
   ELSE IF AtL.Mdtype = Sf THEN
      (* Real compare in normally done by inverting sign, then compare as if
         unsigned integers. Assumes sign-exponent-mantissa representation,
	 (exponent is excess-2**i, and negative numbers NOT complemented) *)
      BEGIN
      IF AtL.Form <> R THEN Loadreg (AtL);
      IF NOT (AtR.Form IN [R,K]) THEN Loadreg (AtR);
      AtL.Mdtype := Su; (* To force unsigned compare *)
      IF (AtR.Form = K) AND (AtR.Cstring.Chars[1] <> '-')
       AND (Op IN [Xgrt, Xgeq]) THEN
         AtL.Mdtype := Ss (* In this case use signed compare *)
      ELSE IF NOT (Op IN [Xequ,Xneq]) THEN
         BEGIN
	 MakintconstAt (TmpAt, 31);	(* Left-most bit *)
	 IF NOT SoleUser (AtL.Reg) THEN Loadreg (AtL);
         Emit2 (bchgl, AtL, TmpAt);
	 IF AtR.Form = K THEN Negate (AtR.Cstring)
         ELSE
	    BEGIN
	    IF NOT SoleUser (AtR.Reg) THEN Loadreg (AtR);
	    Emit2 (bchgl, AtR, TmpAt)
	    END
	 END;
      Emit2 (cmpl, AtL, AtR);
      END
   ELSE IF (AtL.Form = R) OR ((AtR.Form = K) AND (AtL.Form <> K)) THEN
      Emit2 (AdjOcode(cmpl, AtL.Mdtype), AtL, AtR)
   ELSE
      BEGIN LoadReg (AtL); Emit2 (AdjOcode(cmpl, AtR.Mdtype), AtL, AtR); END;

   IF NOT (Op IN [Xand,Xor,Xxor,Xnand,Xnor]) THEN
      BEGIN Clean (AtL); Clean (AtR); END;
   CompareTail (Op, NOT (AtL.Mdtype IN [Qu,Hu,Su]), TgtAt, Dest);
   write(')');
   END;

(*PROCEDURE Loopblockcompare (VAR At1, At2, SizeAt: AddrToken;
			       Outlab: Labl; Cmpunit: Integer);

     * Emits the loop part of a block compare for EQU or NEQ:

        At1 := Addr(At1); At2 := Addr(At2); 
        Loop: IF At1^ <> At2^ THEN Jump to out
              Inc (At1); Inc (At2); Dec (SizeAt); IF SizeAt > 0 goto Loop;

        At the end, At1 and At2 are still valid pointers, and point to
        the next Cmpunit after the last one compared, unless the jump out
        was taken.

        SizeAt Destroyed.
      *

     Var TmpAt1, TmpAt2: Addrtoken;
         Looplab: Labl;

   BEGIN
   Loadreg (SizeAt);
   Getaddr (At1);   Loadreg (At1);
   Getaddr (At2);   Loadreg (At2);
   Createlabel (Looplab);
   Emitlab (Looplab);
   CopyAt (TmpAt1,At1); Indirect (TmpAt1, LentoMdtype (Cmpunit), Cmpunit);
   CopyAt (TmpAt2,At2); Indirect (TmpAt2, LentoMdtype (Cmpunit), Cmpunit);
   Compare (Xneq, NulAt, TmpAt1, TmpAt2, Outlab);
   CopyAt (TmpAt1,At1); CopyAt (TmpAt2,At2);
   Adjaddr (TmpAt1, Cmpunit);  Adjaddr (TmpAt2, Cmpunit);
   Moveit (At1, TmpAt1); Moveit (At2, TmpAt2);
   MakAddrAt (TmpAt1, Sa, 0, LoopLab, Reference);
   Emit2 (dbf, TmpAt1, SizeAt);
   END;
*)
PROCEDURE Inlineblockcompare (VAR At1, At2: AddrToken;
			         Outlab: Labl; Cmpunit, Cmpsize: Integer);

(* Currently NOT USED *)
     (* Emits the inline part of a block compare for EQU or NEQ:

        IF At1 <> At2 THEN	
           Jump to out
        IF (addr(At1)+1)^ <> (addr(At2)+1)^ THEN	
           Jump to out
        IF (addr(At1)+2)^ <> (addr(At2)+2)^ THEN	
           Jump to out
        etc.

        At the end, At1 and At2 point to the next location after the last one
        compared.
     *)

     Var TmpAt1, TmpAt2: Addrtoken;
         Mdty: Mdatatype;
         I: Integer;

   BEGIN
   Mdty := LentoMdtype (Cmpunit);
   At1.Mdtype := Mdty;
   At2.Mdtype := Mdty;
   CopyAt (TmpAt1,At1); CopyAt (TmpAt2,At2);
   Compare (Xneq, NulAt, TmpAt1, TmpAt2, Outlab);
   FOR I := 1 TO Cmpsize - 1 DO
      BEGIN
      Adjobject (At1, Cmpunit, Mdty, Cmpunit);
      Adjobject (At2, Cmpunit, Mdty, Cmpunit);
      CopyAt (TmpAt1,At1); CopyAt (TmpAt2,At2);
      Compare (Xneq, NulAt, TmpAt1, TmpAt2, Outlab);

      END;
   Adjobject (At1, Cmpunit, Mdty, Cmpunit);
   Adjobject (At2, Cmpunit, Mdty, Cmpunit);
   END;

PROCEDURE BlockCompare {(Op: Icode; VAR TgtAt, At1, At2: Addrtoken; Dest: Labl)};
     (* On the 68000, we just call StringCompare *)

   VAR SizeAt: AddrToken;

   BEGIN
   MakintConstAt (SizeAt, At1.Size);
   StringCompare (Op, TgtAt, At1, At2, SizeAt, Dest);
   END;

     (* Emits a compare of two blocks, by blending a judicious use of inline
        comparisons and loop comparisons.  For instance, if a block is 
        19 quarterwords long, it will emit two double-word comparisons and
        three quarter word comparisons.  If it is 83 words long, it will do
        the same except that it will emit a loop to do the double word 
        comparisons.

        If not jumpcompare THEN Tgt  False;

        Compare the blocks, element by element. As soon as there is an
	   inequality,
              IF op = neq and jumpcompare THEN Goto dest ELSE Goto out

        IF op = equ THEN 
           IF jumpcompare then Goto dest 
           ELSE tgt  true
    out:  

     *

   VAR Outlab: Labl;
       Cmpunit, Cmpsize, Remaining: Integer;
       TmpAt, SizeAt: Addrtoken;

   BEGIN
   IF (At1.Mdtype <> M) OR (At2.Mdtype <> M) THEN
      UgenError ('Block compare on non-block.   ',Ord(At1.Mdtype));
   IF (Op <> Xequ) AND (Op <> Xneq) THEN
      UgenError ('Illegal block compare.        ',Ord(Op));
   IF Dest[1] = ' ' THEN
      BEGIN
      IF TgtAt.Form = Empty THEN
	 BEGIN
         TgtAt := ZeroAt;  Loadreg (TgtAt); (* Should be -1 for Xneq *
	 END
      ELSE
	 Moveit (TgtAt, ZeroAt); * might destroy ZeroAt ??? *
      END;
   IF (Op = Xneq) AND (Dest[1] <> ' ') THEN  
      Outlab := Dest
   ELSE  
      Createlabel (Outlab);
   IF At1.Size >= APW*2 THEN
      Cmpunit := APW*2
   ELSE IF At1.Size >= APW THEN
      Cmpunit := APW
   ELSE
      Cmpunit := 1;
   Cmpsize := At1.Size DIV Cmpunit;
   Remaining := At1.Size - Cmpsize * Cmpunit;
   IF Cmpsize <= Loopcutoff THEN
      Inlineblockcompare (At1, At2, Outlab, Cmpunit, Cmpsize) 
   ELSE
      BEGIN
      IF isS1 THEN
	 BEGIN
         Cmpunit := 1;
	 Cmpsize := At1.Size;
	 Remaining := 0;
	 END;
      MakintconstAt (SizeAt, Cmpsize);
      Loopblockcompare (At1, At2, SizeAt, Outlab, Cmpunit);
      IF Remaining > 0 THEN 
	 BEGIN
	 Indirect (At1, At1.Mdtype, At1.Size); 
	 Indirect (At2, At2.Mdtype, At2.Size); 
         END;
      END;
   IF Remaining >= APW THEN
      BEGIN
      Inlineblockcompare (At1, At2, Outlab, APW, 1);
      Remaining := Remaining - APW;
      END;
   IF Remaining > 0 THEN
      BEGIN
      Inlineblockcompare (At1, At2, Outlab, 1, Remaining);
      Remaining := Remaining - APW;
      END;

   IF Op = Xequ THEN
      IF Dest[1] <>  ' ' THEN
	 BEGIN
         MakAddrAt (TmpAt, Sa, 0, Dest, Reference);
         Emit1 (Simplemap[Xjumplab],TmpAt);
         END
      ELSE
	 BEGIN
	 MakintconstAt (TmpAt, -1);
         Moveit (TgtAt, TmpAt);
         END;
   IF (Op = Xequ) OR (Dest[1] = ' ') THEN
      Emitlab (Outlab);
   Clean (At1); Clean (At2)
   END;
** *)

PROCEDURE Stringcompare (*(Op: Icode; VAR TgtAt, At1, At2, SizeAt: AddrToken;
			       Dest: Labl)*);

     (* Emits code to compare two strings.  If Dest is blank, stores result
        in TgtAt.  Otherwise jumps to Dest if comparison true.
	At1, At2, and SizeAt are destroyed and Clean'ed.
	Assumes that the Size is strictly positive!!! *)

   VAR Outlab, LoopLab: Labl;
       TmpAt: Addrtoken; StepSize: Mdatatype;

   BEGIN
   
(*   IF Dest[1] = ' ' THEN
      BEGIN
      IF TgtAt.Form = Empty THEN
	 BEGIN
         TgtAt := ZeroAt;  Loadreg (TgtAt);
	 END
      ELSE
	 Moveit (TgtAt, ZeroAt); * might destrou zeroat ??? *

      END;
   IF (Op = Xneq) AND (Dest[1] <> ' ') THEN  
      Outlab := Dest
   ELSE  
      Createlabel (Outlab);

   Loopblockcompare (At1, At2, SizeAt, Outlab, 1);
*)
   StepSize := Qu;
   IF SizeAt.Form = K THEN
      IF SizeAt.Displ MOD 4 = 0 THEN
         BEGIN SizeAt.Displ:= SizeAt.Displ DIV 4; StepSize:= Su; END
      ELSE IF SizeAt.Displ MOD 2 = 0 THEN
         BEGIN SizeAt.Displ:= SizeAt.Displ DIV 2; StepSize:= Hu; END;
   CreateLabel (OutLab);
   IF (SizeAt.Form = K) AND (SizeAt.Displ > 0) THEN
      BEGIN SizeAt.Displ := SizeAt.Displ - 1; Loadreg (SizeAt); END
   ELSE
      BEGIN Loadreg (SizeAt); SimpleJump (OutLab) END;
   Getaddr (At1);   Loadreg (At1); At1.Form := RIInc;
   Getaddr (At2);   Loadreg (At2); At2.Form := RIInc;
   Createlabel (Looplab);
   Emitlab (Looplab);
   Emit2 (AdjOcode(cmpml, StepSize), At1, At2);
   MakAddrAt (TmpAt, Sa, 0, LoopLab, Reference);
   EmitLab (OutLab);
   Emit2 (dbne, TmpAt, SizeAt);
   Clean (At1); Clean (At2); Clean (SizeAt);

   CompareTail (Op, True, TgtAt, Dest);

(*
   Indirect (At1, LentoMdtype(1), 1); 
   Indirect (At2, At1.Mdtype, 1); 
   IF (Op = Xequ) OR (Op = Xleq) OR (Op = Xgeq) THEN
      IF Dest[1] <> ' ' THEN
	 BEGIN
         MakAddrAt (TmpAt, Sa, 0, Dest, Reference);
         Emit1 (Simplemap[Xjumplab],TmpAt);
         * Clean (TmpAt); *
         END
      ELSE
	 BEGIN
	 MakintconstAt (TmpAt, -1);
         Moveit (TgtAt, TmpAt);
         * Clean (TmpAt); *
         END;
   IF (Op <> Xequ) OR (Dest[1] = ' ') THEN
      Emitlab (Outlab);
   IF (Op = Xequ) AND (Op = Xneq) THEN
      BEGIN
      Clean (At1); Clean (At2)
      END
   ELSE
      Compare (Op, NulAt, At1, At2, Outlab);
*)
   END;

PROCEDURE Emitboundscheck {(VAR At1: Addrtoken; Lowbound, Highbound: Integer)};

   (* Raises error of At1 < Lowbound or At1 > Highbound. *)

   CONST VeryLargeNum = 32767;
   VAR TmpAt, IndexAt: AddrToken;
   BEGIN
   CopyAt (IndexAt, At1);
   IF Lowbound <> 0 THEN
      BEGIN
      Loadreg (IndexAt);
      IF Lowbound <= -Tgtmaxint THEN
         MakintconstAt (TmpAt, Highbound - VeryLargeNum)
      ELSE  
         MakintconstAt (TmpAt, Lowbound);
      Emit2 (subl, IndexAt, TmpAt);
      END
   ELSE IF At1.Form <> R THEN Loadreg(IndexAt);
   IF (Highbound >= Tgtmaxint) OR (Lowbound <= -Tgtmaxint) THEN
      MakintconstAt (TmpAt, VeryLargeNum)
   ELSE
      MakintconstAt (TmpAt, Highbound - Lowbound);
   Emit2 (chk, IndexAt, TmpAt);
   Clean (IndexAt);
(*   JumpifOutofRange (At1, Lowbound, Highbound, Rangechk);*)
   END;

PROCEDURE Checkblock {(VAR At1: Addrtoken; Len: Integer)};

   (* Raises error condition if the block represented by At1 is not all
      zero.  Used when changing the size of a set (ADJ). *)

   BEGIN
   Ugenerror('Check block not implemented',Novalue);
   Clean (At1);
   (*   BlockCompare (Xneq, NulAt, At1, ZeroAt, 'NotZero X');*)
   END;

(* Unpack Extractbyte Depositbyte *)

PROCEDURE Unpack {(VAR At: Addrtoken)};
   (* If At is not a full word long, moves it to a register. *)

   BEGIN
   IF At.Mdtype IN [QS, QU, HS, HU] THEN
      BEGIN
      Loadreg (At);
      At.Mdtype := SS;
      END;
   END;


PROCEDURE Extractbyte {(VAR At:Addrtoken; Bitoffset, Len: Integer;
			SignExtend, Indrct: Boolean)};
   (* Expands a bit-packed quantity into a single word by loading
      it into a work register.  Sets At to describe work reg. *)

   VAR TmpAt,TgtAt: Addrtoken;

   BEGIN
   MakPackedconstAt (TmpAt, Bitoffset, Len);
   TgtAt := NulAt;
   At.Mdtype := Ss;
   IF Signextend THEN
      Emitbinaryop (Xextractsigned, TgtAt, At, TmpAt)
   ELSE
      Emitbinaryop (Xextractunsigned, TgtAt, At, TmpAt);
   Clean (At);
   At := TgtAt;
   END;

PROCEDURE Depositbyte {(VAR TgtAt, At:Addrtoken; Bitoffset, Len: Integer;
			Indrct: Boolean)};

   (* Deposits At into the location TgtAt. *)

   VAR TmpAt: Addrtoken;

   BEGIN
   MakPackedconstAt (TmpAt, Bitoffset, Len);
   Emitbinaryop (Xdeposit, TgtAt, At, TmpAt);
   END;

PROCEDURE ByteIndex {(VAR BaseAt, IndexAt: Addrtoken; Elsize: Integer)};
   BEGIN
   END;

PROCEDURE Index {(VAR BaseAt, IndexAt: Addrtoken; Elsize: Integer)};

   (* Create At representing BaseAt + IndexAt * Elsize.  IndexAt, BaseAt
      destroyed. *)

   VAR At3, At4: Addrtoken;
       I: Integer;

   BEGIN
write('{Index');
   (* Mulitply the top of stack by the element size. *)
   IF Elsize=1 THEN BEGIN END
   ELSE IF PowerofTwo (Elsize,I) THEN
      BEGIN
      IF NOT ColShift (IndexAt, I) THEN
	 BEGIN
         Unpack (IndexAt);
	 MakintconstAt(At3, I);
	 IF I > 8 THEN Loadreg (At3);
	 IF (IndexAt.Form <> R) OR NOT SoleUser (IndexAt.Reg) THEN
	    LoadReg (IndexAt);
	 Emit2 (asll, IndexAt, At3);
	 END
      END
   ELSE
      BEGIN
      MakintconstAt (At3, Elsize);
      At4 := NulAt;
      Emitbinaryop (Xmpy, At4, IndexAt, At3);
      IndexAt := At4;
      END;
    Unpack (IndexAt);
(*    IndexAt.Mdtype := Sa; ??? !!! *)
    (* Now add the base address and multiplied index. *)
    CollapseIndex (BaseAt, IndexAt);
write('}');
    END;

(* Indextable Indexset *)

PROCEDURE Indextable {(VAR Tablepart, IndexAt: Addrtoken; Table: Labl)};

    (* Produces a Address token representing a table of single
       words indexed by an integer, i.e. Table[IndexAt]. IndexAt destroyed. *)

    BEGIN
    MakAddrAt (Tablepart, Sa, 0, Table, Literal);
    Index (Tablepart, IndexAt, APW);
    Indirect (Tablepart, Ss, APW);
    END;

PROCEDURE Indexset {(VAR IndexAt, SetAt, Tablepart, Setpart, DivAt: Addrtoken;
		    Table: Labl)};

   (*  Used for sets, to find the appropriate place
       in a set corresponding to Index DIV Wordsize, and the place
       in a bit table corresponding to Index MOD Wordsize.  More
       precisely: 

	  Tablepart := Table [Index MOD Wordsize];
	  DivAt := Index DIV Wordsize;
	  Setpart := SetAt[Divat];

       IndexAt destroyed. SetAt preserved. 
   *)

   VAR
      TempAt, Temp2At: Addrtoken;
      ModAt: Addrtoken;
      WsAt: Addrtoken;

   BEGIN
   (* DivAt  SourceAt DIV Wordsize; ModAt  SourceAt MOD Wordsize *)
   IF Is68000 THEN
      BEGIN
      ModAt := IndexAt;
      IF NOT Isworkreg (ModAt) OR NOT SoleUser (ModAt.Reg) THEN
         Loadreg (ModAt);
      CopyAt (DivAt, ModAt);
      Loadreg (DivAt);
      MakintconstAt (TempAt, 5);
      Emit2 (asrl, DivAt, TempAt);
      MakintconstAt (TempAt, 31);
      Emit2 (andil, ModAt, TempAt);
      END
   ELSE
      BEGIN
      MakintconstAt (WsAt, Wordsize);
      TempAt := NulAt;
      Emitbinaryop (Xdivmod, TempAt, IndexAt, WsAt);
      SplitAt (TempAt, DivAt, ModAt);
      END;

   Indextable (Tablepart, ModAt, Table);

   (* Now create the token representing SetAt indexed by DivAt*4. *)
   CopyAt (TempAt, DivAt);
   Loadreg (TempAt);
   MakintconstAt(Temp2At, 2);
   Emit2 (asll, TempAt, Temp2At);
   CopyAt (Setpart, Setat);
   Getaddr (Setpart);
   CollapseIndex (Setpart, TempAt);
   Indirect (Setpart, Ss, APW);
   END

(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

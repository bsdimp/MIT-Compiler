(* -- UGCD.PAS -- *)
(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%ift HedrickPascal*)
{  (*$M-*)}
{}
{  PROGRAM Ugat;}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Ug.Inc';}
{   INCLUDE 'Ugrg.Imp';}
{   INCLUDE 'Ugcd.Imp';}
{   INCLUDE 'Ugst.Imp';}
(*%else*)
#include "ucode.h";
#include "ug.h";
#include "ugrg.h";
#include "ugcd.h";
#include "ugst.h";
#include "ugat.h";
(*%endc*)

VAR
   NulAtkn, ZeroAtkn: AddrToken;

(* exported procedures *)

(*%iff UnixPascal*)
{}
{FUNCTION IsTemp (VAR At: Addrtoken): Boolean;}
{   FORWARD;}
{}
{FUNCTION IsBitpacked (VAR U: Bcrec): Boolean;}
{   FORWARD;}
{}
{FUNCTION IsBetween (VAR At: Addrtoken; lo, hi: integer): Boolean;}
{FUNCTION IsOne (VAR At: Addrtoken): Boolean;}
{   FORWARD;}
{}
{FUNCTION IsZero (VAR At: Addrtoken): Boolean;}
{   FORWARD;}
{}
{FUNCTION EquAt (VAR At1, At2: Addrtoken): Boolean;}
{   FORWARD;}
{}
{PROCEDURE CoerceMtypes (VAR At1, At2: Addrtoken);}
{   FORWARD;}
{}
{FUNCTION MachineType (Dtype: Datatype; Len: Integer): Mdatatype;}
{   FORWARD;}
{}
{FUNCTION LenToMdtype (Len: Integer): Mdatatype;}
{   FORWARD;}
{}
{FUNCTION DtypetoCtype (Dtyp: Datatype; VAR Val: Valu): Consttype;}
{   FORWARD;}
{}
{PROCEDURE MakConstAt (VAR At: Addrtoken; VAR U: Bcrec);}
{   FORWARD;}
{}
{PROCEDURE MakregAt (VAR At: Addrtoken; Mdtyp: Mdatatype; Regr: Register);}
{   FORWARD;}
{}
{PROCEDURE MakAddrAt (VAR At: Addrtoken; Mdtyp: Mdatatype;}
{ 		           Dspl: Integer;}
{		           Lbl: Labl; Cntx: Contexts);}
{   FORWARD;}
{}
{PROCEDURE MakrgoffAt (VAR At: Addrtoken; Mdtyp: Mdatatype;}
{			  Rg, Dspl: Integer; Fix: Fixups;}
{		          Cntx: Contexts);}
{   FORWARD;}
{}
{PROCEDURE MakintconstAt (VAR At: Addrtoken; I:Integer);}
{   FORWARD;}
{}
{PROCEDURE MaktempAt (VAR At: Addrtoken; Mdtyp: Mdatatype; Len: Integer;}
{                       Cntx: Contexts);}
{   FORWARD;}
{}
{PROCEDURE MakpackedconstAt (VAR At: Addrtoken; I,J: Integer);}
{   FORWARD;}
{}
{PROCEDURE MakboundspairAt (VAR At: Addrtoken; I,J:Integer);}
{   FORWARD;}
{}
{PROCEDURE Initat;}
{   FORWARD;}
{}
(*%endc*)
FUNCTION IsTemp {(VAR At: Addrtoken): Boolean};
   BEGIN
   Istemp := At.Fixup = Ftemps;
   END;

FUNCTION IsBitpacked {(VAR U: Bcrec): Boolean};
   BEGIN
   IsBitpacked := (U.Length MOD AddrUnit <> 0) OR (U.Offset MOD AddrUnit <> 0);
   END;

FUNCTION IsBetween {(VAR AT: Addrtoken; lo, hi: integer): Boolean:};
   BEGIN
   IsBetween := (AT.Ctype = Intconst) AND (At.Displ >= lo)
      AND (At.Displ <= hi);
   END;
 
FUNCTION IsOne {(VAR At: Addrtoken): Boolean};
   BEGIN
   IsOne := (At.Ctype = Intconst) AND (At.Displ = 1);
   END;

FUNCTION IsZero {(VAR At: Addrtoken): Boolean};
   VAR I: Integer;
   BEGIN
   IF (At.Ctype IN [Realconst,Longrealconst]) AND (IsVax OR Is68000) THEN
      WITH At.Cstring DO
         BEGIN
	 I := 1;
         WHILE Chars[I] IN ['-','+','.','0'] DO I := I + 1;
	 IsZero := Chars[I] IN [' ','E','e'];
         END
   ELSE
      IsZero := (At.Ctype IN [Intconst,Hexconst]) AND (At.Displ = 0);
   END;

FUNCTION EquAt {(VAR At1, At2: Addrtoken): Boolean};
   BEGIN
   EquAt := False;
   WITH At1 DO
      IF (Form = At2.Form) THEN
      EquAt := (Reg = At2.Reg) AND
               (Displ = At2.Displ) AND
               (Labfield = At2.Labfield) AND
               (Fixup = At2.Fixup);
              
   END;

PROCEDURE CoerceMtypes {(VAR At1, At2: Addrtoken)};
   BEGIN
   IF (At1.Ctype = Intconst) AND (At2.Mdtype IN [Qu,Qs,Hu,Hs,Ss]) THEN
      At1.Mdtype := At2.Mdtype
   ELSE IF (At2.Ctype = Intconst) AND (At1.Mdtype IN [Qu,Qs,Hu,Hs,Ss]) THEN
      At2.Mdtype := At1.Mdtype;
   END;

FUNCTION MachineType {(Dtype: Datatype;  Len: Integer): Mdatatype};
 
(* This procedure maps a U-code datatype and a length into a machine data type. *)
   VAR Machtype: Mdatatype;

   BEGIN
   Machtype := ILL;
   CASE Dtype OF
      Adt, Edt: 
	 IF Len = Wordsize THEN Machtype := SA;
      Bdt:
	 IF Len = Wordsize THEN Machtype := SS ELSE
	 IF Len = AddrUnit THEN Machtype := QS;
      Cdt:
	 IF Len = Wordsize THEN Machtype := SS ELSE
	 IF Len = AddrUnit THEN Machtype := QU;
      Idt:
	 IF Len = 2*Wordsize THEN Machtype := DS;
      Jdt:
	 IF Len = WordSize THEN Machtype := SS ELSE
	 IF Len = AddrUnit THEN Machtype := QS ELSE
	 IF Len = 2*AddrUnit THEN Machtype := HS;
      Ldt:
	 IF Len = WordSize THEN Machtype := SS ELSE
	 IF Len = AddrUnit THEN Machtype := QU;
      Rdt:
	 IF Len = Wordsize THEN Machtype := SF;
      Qdt:
	 IF Len = 2*Wordsize THEN Machtype := DF;
      Mdt,Sdt:
	 IF Len = Wordsize THEN Machtype := SS ELSE
	 IF (Len = 2*Wordsize) AND NOT Is68000 THEN Machtype := DS ELSE
	 IF Len MOD AddrUnit = 0 THEN Machtype := M;
      END;
   IF Machtype = ILL THEN
      UgenError ('Data not aligned.             ',Len);
   Machinetype := Machtype;
   END;

FUNCTION DtyptoLen {(Dtyp: Datatype): Integer};
   BEGIN
   IF Is68000 AND (Dtyp IN [Bdt, Cdt]) THEN
      DtyptoLen := 1
   ELSE IF Dtyp IN [Adt, Bdt, Cdt, Edt, Jdt, Ldt, Rdt] THEN
      DtyptoLen := APW
   ELSE IF Dtyp IN [Idt, Qdt] THEN
      DtyptoLen := 2*APW
   ELSE
      UgenError ('Length of complex type.       ',Ord(Dtyp));
   END;

FUNCTION LenToMdtype {(Len: Integer): Mdatatype};

   BEGIN
   IF Len = 1 THEN LenToMdtype := Qs
   ELSE IF Len = 2 THEN LenToMdtype := Hs
   ELSE IF Len = APW THEN LenToMdtype := Ss
   ELSE IF Len = 2*APW THEN LenToMdtype := Ds
   ELSE LenToMdtype := M;
   END;

FUNCTION DtypetoCtype {(Dtyp: Datatype; VAR Val: Valu): Consttype};
   BEGIN
   CASE Dtyp OF
      Adt:
	 IF Val.Ival = -1 THEN
	    DtypetoCtype := Nilconst
         ELSE
	    DtypetoCtype := Addrconst;
      Sdt:
	DtypetoCtype := Setconst;
      Mdt:
	DtypetoCtype := Stringconst;
      Qdt:
	DtypetoCtype := Longrealconst;
      Idt:
	DtypetoCtype := Longintconst;
      Bdt,Cdt,Jdt,Ldt:
        DtypetoCtype := Intconst;
      Rdt:
        DtypetoCtype := Realconst;
      END;
   END;
PROCEDURE MakConstAt {(VAR At: Addrtoken; VAR U: Bcrec)};

(* This routine is used only by the LDC and LCA ucode instructions.  
   It creates an address token which describes the constant specified in the
   ucode instruction U.  Sets, strings, and all doubleword quantities
   are put into the constant area, and their address is put into the address
   token.  Other constants are made into a Constant address token. *)
			   
   BEGIN
      
   At := NulAtkn;
      
   WITH At DO 
      BEGIN
      Size := U.Length DIV AddrUnit;
      (* If constant is a set then create a labelled memory declaration for it. *)
      Ctype := DtypeToCtype (U.Dtype, U.Constval);
      IF Ctype = Stringconst THEN Ctype := Ascizconst;
      CASE Ctype OF
         Setconst:
            IF U.Length = Wordsize THEN
               BEGIN
               Form := K; Cstring := U.Constval; 
	       Context := Literal; Mdtype  := SS;
	       END
	    ELSE
	       BEGIN
               Form := L; 
               Defineconst (U.Constval, U.Length DIV Addrunit, Setconst, Displ);
               GetAreaName (-1, Labfield);
   	       Context := Reference; Mdtype := M;
	       END;
         Ascizconst:
	    BEGIN
            Form := L; 
            Defineconst (U.Constval, U.Length DIV Addrunit, Ctype, Displ);
            GetAreaName (-1, Labfield);
            Context := Literal; Mdtype := SA;
	    END;

         Longrealconst:
	    BEGIN
            Form := L; 
	    Defineconst (U.Constval, U.Length DIV Addrunit, Ctype, Displ);
            GetAreaName (-1, Labfield);
	    Context := Reference; Mdtype := M;
	    END;

         Addrconst, Nilconst:
            BEGIN
            Form := K;
            Mdtype := SA ;
	    Displ := U.Constval.Ival;
            Context := Literal;
            END;

         Intconst:
            BEGIN
            Form := K;
	    Ctype := Intconst;
            Mdtype := SS;
	    Displ := U.Constval.Ival;
	    IF (U.Dtype = Bdt) AND (Displ = 1) THEN Displ := -1;
            Context := Literal;
            END;

         Realconst:
	    BEGIN
	    Form := K;
	    Mdtype := SF;
            Context := Literal;
            Cstring := U.Constval;
	    Ctype := Realconst;
	    END;
         END;
      END;
   END;

PROCEDURE MakregAt {(VAR At: Addrtoken; Mdtyp: Mdatatype; Regr: Register)};
   BEGIN
   At := NulAtkn;
   WITH At DO 
      BEGIN
      Mdtype := Mdtyp;
      Context := Reference;
      Form := R;
      Reg := Regr;
      END;
   END;

PROCEDURE MakTmpRegAt {(VAR At: Addrtoken; Mdtyp: Mdatatype)};
   VAR Treg: Register;
   BEGIN
   Treg := AllocateReg (Mdtyp);
writeln('Alloc/MakTmpRegat/ugat. T:',Mdtyp,' reg:', Treg);
   At := NulAtkn;
   WITH At DO 
      BEGIN
      Mdtype := Mdtyp;
      Context := Reference;
      Form := R;
      Reg := Treg;
      END;
   END;

PROCEDURE MakAddrAt {(VAR At: Addrtoken; Mdtyp: Mdatatype;
 		           Dspl: Integer; Lbl: Labl; Cntx: Contexts)};

(* This routine creates an address token.  IF EXT is true, the address
   is external. *)

   BEGIN

   At := NulAtkn;

     (* Construct An Address Token *)
   WITH At DO 
      BEGIN
      Mdtype := Mdtyp;
      Form := L;
      Displ := Dspl;
      Labfield := Lbl;
      Context := Cntx;
      END;

   END;
PROCEDURE MakrgoffAt {(VAR At: Addrtoken; Mdtyp: Mdatatype;
			  Rg, Dspl: Integer; Fix: Fixups;
		          Cntx: Contexts)};

CONST
   LowSd = -128;
   HighSd = 124;
(* This routine creates a register offset token. *)

   BEGIN

     (* Initialize *)
   At := NulAtkn;

     (* Construct An Address Token *)
   WITH At DO 
      BEGIN
	 Form := DR;
	 Displ := Dspl;
      Reg := Rg;
      Context := Cntx;
      Fixup := Fix;
      Mdtype := Mdtyp;
      END;

   END;
PROCEDURE MakintconstAt {(VAR At: Addrtoken; I:Integer)};
(* This routine creates a token which describes an integer constant. *)

   BEGIN
   At := ZeroAtkn;
   At.Displ := I;
   END;

PROCEDURE MaktempAt {(VAR At: Addrtoken; Mdtyp: Mdatatype; Len: Integer;
                       Cntx: Contexts)};

(*  This routine allocates a temporary block of the appropriate LEN (in bits), and
    creates an address token which describes this temporary location. *)


   VAR

      Tptr: Tempptr;
      Toffset: Integer;

   BEGIN
   IF Len <= 0 THEN (* hack !!! *)
      IF Mdtyp IN [Ss,Su,Sa,Sf] THEN Len := APW
      ELSE IF Mdtyp IN [Df,Ds] THEN Len := 2*APW
      ELSE Len := 2;
   Gettemp (Tptr, Len, Toffset);
      (* Make an appropriate Operand Token *)
   MakrgoffAt (At, Mdtyp, Fp, Toffset, Ftemps, Cntx);
   At.Tmpptr := Tptr;
   At.Size := Len;
   END;


PROCEDURE MakpackedconstAt {(VAR At: Addrtoken; I,J: Integer)};
   Const
      Shifthalf = 262144;    (* used to manually pack records *)
   VAR Ct: Valu;

(* This routine creates an address token describing two integer that are
   packed into the left and right halves, respectively, of a full word 
   constant. *)

   BEGIN
   At := NulAtkn;
   At.Form := L; 
   GetAreaName (-1, At.Labfield);
   At.Context := Literal; 
   At.Mdtype := SS;
   At.Ctype := Packedconst;
   Ct.Ival := I * Shifthalf + J;
   Defineconst (Ct, APW, Intconst, At.Displ);
   END;

PROCEDURE MakboundspairAt {(VAR At: Addrtoken; I,J:Integer)};
(* This routine creates an address token describing two integer constants.
   If they both will fit in a half word, a special constant is created.
   Otherwise, they are assigned a place in the constants area. *)

   VAR Ct: Valu;
   BEGIN
   At := NulAtkn;
   At.Form := L; 
   GetAreaName (-1, At.Labfield);
   At.Context := Literal; 
   At.Mdtype := SS;
   At.Ctype := Packedconst;
   Ct.Ival := I;
   Defineconst (Ct, APW, Intconst, At.Displ);
   Ct.Ival := J;
   Defineconst (Ct, APW, Intconst, I);
   END;

PROCEDURE Initat{};
   (* Initializes AT module. *)
   BEGIN 
   WITH NulAtkn DO
      BEGIN
      Mdtype := ILL;
      Form := Empty;
      Size := 0;
      Context := Literal;
      Reg := -1;
      Reg2 := -1;
      Displ := 0;
      Labfield := Blabl;
      Extlab := False;
      Fixup := Fnone;
      Tmpptr := NIL;
      Ctype := Notconst;
      END;
   ZeroAtkn := NulAtkn;
   WITH ZeroAtkn DO
      BEGIN
      Mdtype := Ss;
      Form := K;
      Ctype := Intconst;
      END;
   END

(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

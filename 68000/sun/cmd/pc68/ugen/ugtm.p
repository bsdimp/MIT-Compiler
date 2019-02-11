(* -- UGTM.PAS -- *)
(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%iff UnixPascal*)
{  (*$M-*)}
{}
{  PROGRAM UGTM;}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Ug.Inc';}
{   INCLUDE 'Ugcd.Imp';}
(*%else*)
#include "ucode.h";
#include "ug.h";
#include "ugcd.h";
#include "ugtm.h";
(*%endc*)
(* exported procedures *)

(*%iff UnixPascal*)
{}
{FUNCTION Collindirect (VAR At: Addrtoken): Boolean;}
{   FORWARD;}
{}
{FUNCTION Colladjust (VAR At: Addrtoken; Adjlength : Integer): Boolean;}
{   FORWARD;}
{}
{FUNCTION Coladaddr (VAR At1,At2: Addrtoken) : Boolean;}
{   FORWARD;}
{}
{FUNCTION ColShift (VAR At: AddrToken; Shft: Integer): Boolean;}
{   FORWARD;}
{}
{FUNCTION ColAdInt (VAR At1, At2: AddrToken): Boolean;}
{   FORWARD;}
{}
{PROCEDURE InitTm;}
{   FORWARD;}
{}
(*%endc*)
FUNCTION Collindirect {(VAR At: Addrtoken): Boolean};

   BEGIN
write('[Collindirect:ctx:',At.Context,']');
   Collindirect := True;
   WITH At DO
      IF Context = Literal THEN Context := Reference
      ELSE Case Form OF
	 K: UgenError ('Illegal indirection.          ',Novalue);
	 R: Form := RI;
         RIInc, RIDec, RIR, DR, RI, L:  Collindirect := False;
         END;
   END;

FUNCTION Colladjust {(VAR At: Addrtoken; Adjlength : Integer): Boolean};
(* This routine attempts to adjust the Address passed to it by the number of whole 
   words passed in adjust length.  Note that this offset can be negative.*)

   VAR Error: Boolean;

   BEGIN
   Colladjust := True;
   WITH At DO
      IF Context = Literal THEN Case Form OF
	 K,R:	UgenError ('Illegal literal address.      ',Novalue);
	 L,DR:	Displ := Displ + Adjlength;
	 RI:	BEGIN Form := DR; Displ := Adjlength; END;
	 RIR:	IF Abs (Displ + Adjlength) < 128 THEN
		   Displ := Displ + AdjLength
		ELSE Colladjust := False;
	 RIInc,RIDec:  Colladjust := False;
         END
      ELSE CASE Form OF
	 K: UgenError ('Illegal constant address.     ',Novalue);
	 R: BEGIN Context := Literal; Form := DR; Displ := Adjlength; END;
	 RIR,RI,DR,L,RIInc,RIDec:  Colladjust := False;
         END;
   END;

FUNCTION Coladaddr {(VAR At1,At2: Addrtoken) : Boolean};
(* This function Does a lookup in the proper collapse table to see if 
   it possible to collapse the addition of the two operands into the address
   calculation of one operand.  If the collapse is possible, At1 is
   updated to be the result operand, and the function returns true.  If no
   collapse is possible, the function returns false, and the operands
   are unchanged.*)


   BEGIN
 write('Coladaddr<',At1.Form,'/',At1.Context,'/',At1.Displ:1,'+',At2.Form);
   IF (At2.Form = R) AND (At2.Context = Reference) AND
      (((At1.Form = R) AND (At1.Context = Reference)) OR
       ((At1.Form = RI) AND (At1.Context = Literal)) OR
       ((At1.Form = DR) AND (At1.Context = Literal) AND
        (At1.Displ >= -128) AND (At1.Displ < 128) AND (At1.Reg <> Fp))
      ) THEN
        BEGIN
	At1.Form := RIR;
	At1.Reg2 := At2.Reg;
	At1.Context := Literal;
	Coladaddr := True;
write('=>RIR');
	END
   ELSE
      Coladaddr := False;
write('>');
   END;

FUNCTION ColShift {(VAR At: AddrToken; Shft: Integer): Boolean};
   (* Attempts to collapse an integer shift into an address token. *)

   BEGIN
   ColShift := False;
   END;

FUNCTION ColAdInt {(VAR At1, At2: AddrToken): Boolean};
   (* IF one address token is a constant and the other a register,
      collapses them into an indexed constant, thus saving an ADD
      instruction.  Resulting address token is left in At1.
   *)

   BEGIN
   UgenError ('ColAdint called.              ',Novalue);
   ColAdInt := False;
   END;

PROCEDURE InitTm{};

   BEGIN
   END
(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

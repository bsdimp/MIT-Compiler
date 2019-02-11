(* -- UGCD.PAS -- *)
(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%ift HedrickPascal*)
{  (*$M-*)}
{}
{  PROGRAM Ugcd;}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Ug.Inc';}
{   INCLUDE 'Ugat.Imp';}
{   INCLUDE 'Ugst.Imp';}
{   INCLUDE 'Ugrg.Imp';}
{}
(*%else*)
#include "ucode.h";
#include "ug.h";
#include "ugat.h";
#include "ugst.h";
#include "ugrg.h";
#include "ugcd.h";
(*%endc*)

(* This module manages the object code.  The procedures Emit2, Emit3, etc.
cause a new instruction to be inserted into the linked list of instructions.
Once the instructions for an entire procedure have been generated, a peephole
pass does all the fixups and some peephole optimization.   Then the procedure
is written to the object file.
*)
CONST
   AsmComment = '|';	(* Comment symbol used by assembler *)
   Indent = '	'; (* amount each instruction is indented in asmb. file. *)

   MaxDecDigits = 18;	(* Max digits for decimal double float *)
   MaxBinDigits = 56;	(* Max bits mantissa for double float *)
   MaxBinSingle = 24;	(* D. for single precision *)
   MaxPosExp = 127;	(* Largest postive exponent in float *)
   MaxExpPlus1 = 128;	(* MaxPosExp + 1 *)
   MaxNegExp = -127;	(* Smallest  negative exponent infloat *)
   LeastBit = -184;	(* MaxNegBit - MaxBinDigits - 1*)

TYPE
   (* Various stuff used to convert real constants *)
   (* For both Decimal- and BinaryFloat, the decimal/binary point
    * is between Mantissa[1] and Mantissa[2]. *)
   DecimalFloat = RECORD
      Exponent: Integer;
      Mantissa: PACKED ARRAY [1..MaxDecDigits] OF 0..9;
      END;
   BinaryFloat = RECORD
      Exponent: Integer;
      Mantissa: PACKED ARRAY [1..MaxBinDigits] OF 0..1;
      END;
   SignCode = -1..1;

   (* Appearance of instructions in the assembler file: *)

   Opformat = (Fakeop, OP0, OP1, TOP, JOP, XOP, SOP, HOP);
   Rgnam = PACKED ARRAY[1..2] OF Char;   (* String representation of registers. *)
   Oname = PACKED ARRAY[1..8] OF Char;  (* String representation of instruction. *)

   (* This represents an instruction: *)

   Instptr = ^Inst;
   Inst = 
      RECORD
      Op: Ocode;
      Format: Opformat;
      Od1, Od2: Addrtoken;
      Next, Last: Instptr;
      END;

VAR

   Afile: Text;			  (* the assembler file *)
   Source: Text;		  (* the original source *)
   Sourcename: Filename;	  (* name or source, passed through the U-code *)
   CurrPage, Currline: Integer;	  (* current page, line of source file in U-code *)
   Spage, Sline: Integer;	  (* last page, line read from source file *)

   Writetime: Integer;		  (* execution count *)
   Instrcnt: Integer;		  (* count of number of instruction emitted *)
   Codehead, Codetail: Instptr; (* Head and tail of code for this procedure *)
   Tcode: Boolean;		(* trace code as it is emitted? *)

   Regname: ARRAY [Register] OF Rgnam;  (* string repr. of registers *)
   Mnems: ARRAY [Ocode] OF Oname;	(* string representation of instructions *)
   HexDigits: PACKED ARRAY [1..16] OF Char;   
   PowersOk: BOOLEAN;	(* True if TwoToThe has been initialized *)
   (* 2**i in decimal*)
   TwoToThe: ARRAY [LeastBit..MaxExpPlus1] OF DecimalFloat;

(* Eopage Lblen *)

FUNCTION Curtime{: Integer};
   BEGIN
   (*%ift HedrickPascal*)
{   Curtime := Runtime;}
   (*%else*)
   Curtime := Clock;
   (*%endc*)
   END;

PROCEDURE Resetsource {(VAR Sname: Filename)};
   BEGIN
   Sourcename := Sname;
   (*%ift HedrickPascal*)
{   Reset (Source, Sourcename, '/E');}
   (*%else*)
   Reset (Source, Sourcename);
   (*%endc*)
   Spage := 1;
   Sline := 1;
   END;

FUNCTION Eopage(VAR Fil: Text): Boolean;

   (* Returns true if a formfeed is in the current file buffer.
      Should be set to FALSE if this capability is not available. *)
   
   CONST
      Formfeed = 12;

   BEGIN (*eopage*)
   Eopage := Ord(Fil^) = formfeed;
   END (*eopage*);

PROCEDURE LabTrans (VAR Lbl: Labl);
   (* Translate '$' to '_', upper case to lower case in Lbl *)
   (* Assume the character set is Ascii! *)
   VAR I: Integer;
   BEGIN
   Lbl[Labcharsp1] := ' ';	(* Note! *)
   IF Lbl[1] = '.' THEN I := 3 ELSE I := 1;
   WHILE I <= Labchars DO
      BEGIN
      IF Lbl[I] = '$' THEN Lbl[I] := '_';
      IF (Lbl[I] >= 'A') AND (Lbl[I] <= 'Z') THEN
         Lbl[I] := Chr(Ord(Lbl[I]) + Ord('a') - Ord('A'));
      I := I + 1;
      END;
   END;

FUNCTION Lblen (VAR Lbl: Labl): Integer;
    (* returns number characters in a label, excluding trailing blanks *)
    VAR I: Integer;
    BEGIN
    I := Labchars;
    While (Lbl[I] = ' ') AND (I > 0) DO
        I := I - 1;
    Lblen := I;
    END;

PROCEDURE PrntError (VAR Fil: Text; Msg: Errstring; Value: Integer);

   BEGIN
   Write (Fil, AsmComment, 'Error');
   IF CurrPage > 0 THEN
      Write (Fil, ' at page ', CurrPage:1, ' line ',Currline:1);
   IF Value <> Novalue THEN
      Write (Fil, ' value ',Value:1);
   Writeln (Fil,AsmComment);
   Writeln (Fil,AsmComment,Msg);
   END;

PROCEDURE UgenError {(Msg: Errstring; Value: Integer)};

   BEGIN
   Writeln (Output);
   PrntError (Output, Msg, Value);
   PrntError (Afile, Msg, Value);
   END;

PROCEDURE UgenMsg {(Msg: Errstring; Value: Integer)};

   BEGIN
   IF Value <> Novalue THEN
      Writeln (Afile, AsmComment, Msg,'; Value = ',Value:1)
   ELSE Writeln (Afile,AsmComment,Msg);
   END;

PROCEDURE LoadOpnameTable;

BEGIN
  (* Note op's marked with a comment differ *)
   Mnems[Ploc	] := 'Ploc    ';
   Mnems[Pillegal]:= '<Badop> ';
   Mnems[Pstart	] := 'Pstart  ';
   Mnems[Plab	] := 'Plab    ';
   Mnems[movb	] := 'movb    ';
   Mnems[movw	] := 'movw    ';
   Mnems[movl	] := 'movl    ';
   Mnems[movemw	] := 'movemw  ';
   Mnems[moveml	] := 'moveml  ';
   Mnems[moveq	] := 'moveq   ';
   Mnems[exg	] := 'exg     ';
   Mnems[swap	] := 'swap    ';
   Mnems[link	] := 'link    ';
   Mnems[unlk	] := 'unlk    ';
   Mnems[lea	] := 'lea     ';
   Mnems[pea	] := 'pea     ';
   Mnems[addaw	] := 'addw    ';	(* *)
   Mnems[addal	] := 'addl    ';	(* *)
   Mnems[addb	] := 'addb    ';
   Mnems[addw	] := 'addw    ';
   Mnems[addl	] := 'addl    ';
   Mnems[addib	] := 'addb    ';	(* *)
   Mnems[addiw	] := 'addw    ';	(* *)
   Mnems[addil	] := 'addl    ';	(* *)
   Mnems[addqb	] := 'addqb   ';
   Mnems[addqw	] := 'addqw   ';
   Mnems[addql	] := 'addql   ';
   Mnems[subaw	] := 'subw    ';	(* *)
   Mnems[subal	] := 'subl    ';	(* *)
   Mnems[subb	] := 'subb    ';
   Mnems[subw	] := 'subw    ';
   Mnems[subl	] := 'subl    ';
   Mnems[subib	] := 'subb    ';	(* *)
   Mnems[subiw	] := 'subw    ';	(* *)
   Mnems[subil	] := 'subl    ';	(* *)
   Mnems[subqb	] := 'subqb   ';
   Mnems[subqw	] := 'subqw   ';
   Mnems[subql	] := 'subql   ';
   Mnems[muls	] := 'muls    ';
   Mnems[mulu	] := 'mulu    ';
   Mnems[divs	] := 'divs    ';
   Mnems[divu	] := 'divu    ';
   Mnems[negb	] := 'negb    ';
   Mnems[negw	] := 'negw    ';
   Mnems[negl	] := 'negl    ';
   Mnems[extw	] := 'extw    ';
   Mnems[extl	] := 'extl    ';
   Mnems[clrb	] := 'clrb    ';
   Mnems[clrw	] := 'clrw    ';
   Mnems[clrl	] := 'clrl    ';
   Mnems[cmpaw	] := 'cmpw    ';	(* *)
   Mnems[cmpal	] := 'cmpl    ';	(* *)
   Mnems[cmpb	] := 'cmpb    ';
   Mnems[cmpw	] := 'cmpw    ';
   Mnems[cmpl	] := 'cmpl    ';
   Mnems[cmpib	] := 'cmpb    ';	(* *)
   Mnems[cmpiw	] := 'cmpw    ';	(* *)
   Mnems[cmpil	] := 'cmpl    ';	(* *)
   Mnems[cmpmb	] := 'cmpmb   ';
   Mnems[cmpmw	] := 'cmpmw   ';
   Mnems[cmpml	] := 'cmpml   ';
   Mnems[tstb	] := 'tstb    ';
   Mnems[tstw	] := 'tstw    ';
   Mnems[tstl	] := 'tstl    ';
   Mnems[andb	] := 'andb    ';
   Mnems[andw	] := 'andw    ';
   Mnems[andl	] := 'andl    ';
   Mnems[andib	] := 'andb    ';	(* *)
   Mnems[andiw	] := 'andw    ';	(* *)
   Mnems[andil	] := 'andl    ';	(* *)
   Mnems[orb	] := 'orb     ';
   Mnems[orw	] := 'orw     ';
   Mnems[orl	] := 'orl     ';
   Mnems[orib	] := 'orb     ';	(* *)
   Mnems[oriw	] := 'orw     ';	(* *)
   Mnems[oril	] := 'orl     ';	(* *)
   Mnems[eorb	] := 'eorb    ';
   Mnems[eorw	] := 'eorw    ';
   Mnems[eorl	] := 'eorl    ';
   Mnems[eorib	] := 'eorb    ';	(* *)
   Mnems[eoriw	] := 'eorw    ';	(* *)
   Mnems[eoril	] := 'eorl    ';	(* *)
   Mnems[notb	] := 'notb    ';
   Mnems[notw	] := 'notw    ';
   Mnems[notl	] := 'notl    ';
   Mnems[aslb	] := 'aslb    ';
   Mnems[aslw	] := 'aslw    ';
   Mnems[asll	] := 'asll    ';
   Mnems[asrb	] := 'asrb    ';
   Mnems[asrw	] := 'asrw    ';
   Mnems[asrl	] := 'asrl    ';
   Mnems[lslb	] := 'lslb    ';
   Mnems[lslw	] := 'lslw    ';
   Mnems[lsll	] := 'lsll    ';
   Mnems[lsrb	] := 'lsrb    ';
   Mnems[lsrw	] := 'lsrw    ';
   Mnems[lsrl	] := 'lsrl    ';
   Mnems[rolb	] := 'rolb    ';
   Mnems[rolw	] := 'rolw    ';
   Mnems[roll	] := 'roll    ';
   Mnems[rorb	] := 'rorb    ';
   Mnems[rorw	] := 'rorw    ';
   Mnems[rorl	] := 'rorl    ';
   Mnems[btstb	] := 'btst    ';	(* *)
   Mnems[btstl	] := 'btst    ';	(* *)
   Mnems[bchgb	] := 'bchg    ';	(* *)
   Mnems[bchgl	] := 'bchg    ';	(* *)
   Mnems[bsetb	] := 'bset    ';	(* *)
   Mnems[bsetl	] := 'bset    ';	(* *)
   Mnems[bclrb	] := 'bclr    ';	(* *)
   Mnems[bclrl	] := 'bclr    ';	(* *)
   Mnems[dbf	] := 'dbf     ';
   Mnems[dbne	] := 'dbne    ';
   Mnems[jmp	] := 'jmp     ';
   Mnems[jsr	] := 'jsr     ';
   Mnems[rts	] := 'rts     ';
   Mnems[scc	] := 'scc     ';
   Mnems[scs	] := 'scs     ';
   Mnems[seq	] := 'seq     ';
   Mnems[sfalse	] := 'sf      ';	(* *)
   Mnems[sge	] := 'sge     ';
   Mnems[sgt	] := 'sgt     ';
   Mnems[shi	] := 'shi     ';
   Mnems[sle	] := 'sle     ';
   Mnems[sls	] := 'sls     ';
   Mnems[slt	] := 'slt     ';
   Mnems[smi	] := 'smi     ';
   Mnems[sne	] := 'sne     ';
   Mnems[spl	] := 'spl     ';
   Mnems[strue	] := 'st      ';
   Mnems[svc	] := 'svc     ';
   Mnems[svs	] := 'svs     ';
   Mnems[jcc	] := 'jcc     ';
   Mnems[jcs	] := 'jcs     ';
   Mnems[jeq	] := 'jeq     ';
   Mnems[jge	] := 'jge     ';
   Mnems[jgt	] := 'jgt     ';
   Mnems[jhi	] := 'jhi     ';
   Mnems[jle	] := 'jle     ';
   Mnems[jls	] := 'jls     ';
   Mnems[jlt	] := 'jlt     ';
   Mnems[jmi	] := 'jmi     ';
   Mnems[jne	] := 'jne     ';
   Mnems[jpl	] := 'jpl     ';
   Mnems[jvc	] := 'jvc     ';
   Mnems[jvs	] := 'jvs     ';
   Mnems[jra	] := 'jra     ';
   Mnems[bra	] := 'bra     ';
   Mnems[chk	] := 'chk     ';
   END;

PROCEDURE SetCdVar {(Varbl:SharedVar; Val: Integer)};
   BEGIN
   IF Varbl = ShTrace THEN
      Tcode := Odd (Val DIV 2);
   END;

PROCEDURE TraceUcode {(U: Bcrec; Mnem: Opcstring)};
   (* Prints out current Ucode opcode in object file, for tracing. *)
   BEGIN
   Writeln (Afile, AsmComment, Mnem);
   END;

PROCEDURE Writstats {(Inittime, Readtime, Asmtime: Integer)};

   VAR
       Percentage, Bindcnt, Loadcnt: Integer;
   BEGIN
   (* print statistics *)

   IF Binding THEN
      BEGIN
      Getstats (Bindcnt, Loadcnt);  (* from RG module *)
      Writeln (Afile,AsmComment,Instrcnt:5,' Instructions Emitted.');
      IF Loadcnt > 0 THEN 
	  BEGIN
	  Percentage := 0;
	  IF (Bindcnt <> 0) THEN
	      BEGIN
	      Percentage := 100*Bindcnt DIV (Bindcnt+Instrcnt);
	      Writeln (Afile,AsmComment,Bindcnt:5,' = ',percentage:2,
		       '% instructions saved by Binding.');
	      Percentage := 100*Bindcnt DIV (Loadcnt+Bindcnt);
	      Writeln (Afile,AsmComment,Bindcnt:5,' = ',percentage:2,
		       '% of register loads saved by Binding.');
	      END
	  END;
      END;
   Writeln (Afile, AsmComment, ' Init = ', Inittime:1,' Read = ', Readtime:1,
	    ' Asm = ',Asmtime-Writetime:1, ' Write = ', Writetime:1);
   END;


PROCEDURE WritComment {(VAR U: Bcrec)};
   BEGIN
   Writeln (Afile, AsmComment, U.Constval.Chars: U.Constval.Len);
   END;

PROCEDURE Endfile {(Main: Labl; Profile: Boolean)};
  
      (* Writes out entry point in object file, followed by call to main block,
	 follownd by call to profiler, if Profile is turned on. *)
   BEGIN
   IF Main[1] = ' ' THEN
      Writeln (Afile, Indent, '.end')
   ELSE
      BEGIN
      Writeln (Afile);
      Writeln (Afile, Indent, '.globl main');
      Writeln (Afile, 'main:');
      Writeln (Afile, '	movl	sp,.savsp');
      Writeln (Afile, '	movl	#/FFFE,sp');	(* !!! *)
      LabTrans (Main);
      Writeln (Afile, Indent, 'jsr	', Main:8);
      Writeln (Afile, '	movl	.savsp,sp');
      Writeln (Afile, '	rts');
      Writeln (Afile, '	.data');
      Writeln (Afile, '.savsp:	.blkl	4');
(*      Writeln (Afile, Indent, '.globl $INITALL');
      Writeln (Afile, 'Entry:  ');
      *set up stack and initialize runtimes*
      Writeln (Afile, Indent, 'JSP          ','$INITALL-4,$INITALL');
      Writeln (Afile, Indent, 'CALL         ',Regname[CP],',',Main);
*)
      IF Profile THEN
	 BEGIN
	 Writeln (Afile, Indent, 'External $PROF');
(*	 Writeln (Afile, Indent, 'CALL         ',Regname[CP],',$PROF');*)
	 END;
(*      Writeln (Afile, Indent, 'HALT .');
      Writeln (Afile, Indent, 'END ENTRY'); *)
      END
   END;

PROCEDURE RuntimeRequest {(Runset: Integer)};
   BEGIN
   END;

PROCEDURE Putlab {(Lb: Labl; Disp: Integer; Defining: Boolean; Comment: Identname)};
   BEGIN
   LabTrans (Lb);
   IF Defining THEN Writeln (Afile, '	.globl	', Lb:Lblen(Lb))
   ELSE Write (Afile, ' ');
   Write (Afile, Lb:Lblen(Lb));
   IF Disp <> 0 THEN
      Write (Afile, '+',Disp:1);
   IF Defining then Write (Afile, ':');
   IF Comment[1] <> ' ' THEN Write (Afile, AsmComment,' ', Comment);
   Writeln (Afile);
   END;

PROCEDURE Putint {(I: Integer)};
   BEGIN
   Writeln (Afile, '	.long	',I:1);
   END;

PROCEDURE Putblock {(Size: Integer)};
   BEGIN
   Writeln (Afile, '	.blkb	', Size:1);
   END;

PROCEDURE Putpacked {(Left, Right: Integer)};
   BEGIN
   Writeln (Afile, ' ', Left:1, ',,', Right:1);
   END;

PROCEDURE Putid {(Id: Identname)};
   BEGIN
   Writeln (Afile, indent, '.ascii	"', Id, '"'); 
   END;

PROCEDURE Putfname {(Fn: Filename)};
   BEGIN
   Writeln (Afile, indent, '.ascii', '"', Fn, '"'); 
   END;

PROCEDURE StartArea {(Arealab: Labl; Areanum, Arealength: Integer;
		      Initialized: Boolean)};
   (* Starts a static area.  If areanum > 1, then it is a Fortran common.
      If Initialized is true, then it is initialized (Block Common) *)
   BEGIN
   LabTrans (Arealab);
   Writeln (Afile, '	.data');
   Write (Afile, Arealab:Lblen(Arealab), ': ', AsmComment);
   IF Areanum = -1 THEN
     (* local constants *)
      Writeln (Afile, 'constants')
   ELSE IF Areanum = 1 THEN
     (* global area *)
      Writeln (Afile, 'global variables')
   ELSE
      BEGIN (* common area *)
      Writeln (Afile, 'common area')
      END;
   END;

PROCEDURE EndArea {(Areanum, Arealength: Integer)};
   (* ends static area *)
   BEGIN
   Writeln (Afile, '	.text');
   END;

PROCEDURE WritHex (Val: Integer);
   (* Writes Val in Hex on Afile. Val should be positive. *)
   VAR
      Quot, Rem: Integer;
   BEGIN
      IF Val < 0 THEN BEGIN Val := -Val; Write (Afile, '-') END;
      Quot:= Val div 16; Rem := Val mod 16;
      IF Quot > 0 THEN WritHex (Quot);
      Write (Afile, HexDigits[Rem + 1]);
   END;

(* Procedures to write a real as a hex literal. First initialize TwoToThe *)

PROCEDURE DoubleDec (VAR Outp, Inp: DecimalFloat);
   VAR I, Carry, Digit: Integer;
   BEGIN
   Carry := 0;
   FOR I := MaxDecDigits DOWNTO 1 DO
      BEGIN
      Digit := Inp.Mantissa[I] + Inp.Mantissa[I] + Carry;
      Carry := Ord (Digit >= 10);
      IF Carry > 0 THEN Digit := Digit - 10;
      Outp.Mantissa[I] := Digit;
      END;
   IF Carry = 0 THEN Outp.Exponent := Inp.Exponent
   ELSE
      BEGIN
      Outp.Exponent := Inp.Exponent + 1;
      FOR I := MaxDecDigits DOWNTO 2 DO
         Outp.Mantissa[I] := Outp.Mantissa[I - 1];
      Outp.Mantissa[1] := Carry;
      END;
   END;

PROCEDURE HalveDec (VAR Outp, Inp: DecimalFloat);
   VAR IIn, IOut, Prev: Integer;
   BEGIN
   IIn := 1; Iout := 1; Outp.Exponent := Inp.Exponent; Prev := 0;
   IF Inp.Mantissa[1] = 1 THEN
      BEGIN IIn := 2; Outp.Exponent := Inp.Exponent - 1; Prev := 5 END;
   WHILE IIn <= MaxDecDigits DO
      BEGIN
      Outp.Mantissa[IOut] := Inp.Mantissa[IIn] DIV 2 + Prev;
      IF Odd(Inp.Mantissa[IIn]) THEN Prev := 5 ELSE Prev := 0;
      IIn := IIn + 1; IOut := IOut + 1;
      END;
   IF IOut <= MaxDecDigits THEN Outp.Mantissa[IOut] := Prev;
   END;

PROCEDURE InitDec;
   VAR I: Integer;
   BEGIN
   WITH TwoToThe[0] DO
      BEGIN
      Exponent := 0; Mantissa[1] := 1;
      FOR I := 2 TO MaxDecDigits DO Mantissa[I] := 0;
      END;
   FOR I := 1 TO MaxExpPlus1 DO DoubleDec (TwoToThe[I], TwoToThe[I-1]);
   FOR I := -1 DOWNTO LeastBit DO HalveDec (TwoToThe[I], TwoToThe[I+1]);
   END;

FUNCTION SubtractDec (VAR Dec1, Dec2: DecimalFloat):SignCode;
   (* IF Dec1 >= Dec2 THEN Dec1 := Dec1 - Dec2; Result := Signum(Dec1-Dec2) *)
   VAR
      Work: PACKED ARRAY [1..MaxDecDigits] OF 0..9;
      I, Diff, Delta, Borrow: Integer;
   BEGIN
   Delta := Dec1.Exponent - Dec2.Exponent;
   IF Delta < 0 THEN SubtractDec := -1
   ELSE
      BEGIN
      Borrow := 0;
      FOR I := MaxDecDigits DOWNTO 1 DO
         BEGIN
	 IF I > Delta THEN Borrow := Borrow + Dec2.Mantissa[I - Delta];
	 Diff := Dec1.Mantissa[I] - Borrow;
	 Borrow := Ord(Diff < 0);
	 Work[I] := Diff + 10*Borrow;
	 END;
      IF Borrow > 0 THEN SubtractDec := -1
      ELSE
         BEGIN
         I := 1;
         WHILE (Work[I] = 0) AND (I < MaxDecDigits) DO I := I + 1;
         Delta := I - 1;
	 IF Work[I] = 0 THEN
	    BEGIN SubtractDec:= 0; Dec1.Exponent := 0 END
	 ELSE
	    BEGIN SubtractDec:= 1; Dec1.Exponent := Dec1.Exponent - Delta END;
         FOR I := 1 TO MaxDecDigits - Delta DO
            Dec1.Mantissa[I] := Work[I + Delta];
	 FOR I := MaxDecDigits - Delta + 1 TO MaxDecDigits DO
	    Dec1.Mantissa[I] := 0;
	 END;
      END;
   END;

PROCEDURE WriteReal (VAR C: Valu; Double: Boolean);
   VAR I, J, BitPos, Sign: Integer; NegExp, Negative: Boolean;
      Bin: BinaryFloat; Dec: DecimalFloat; 

   PROCEDURE Getdigits;
   BEGIN
   WHILE (C.Chars[I] >= '0') AND (C.Chars[I] <= '9') DO
      BEGIN
      IF J <= MaxDecDigits THEN
         BEGIN Dec.Mantissa[J]:= Ord(C.Chars[I]) - Ord('0'); J := J+1; END;
      I := I + 1;
      END;
   END;
   
   PROCEDURE PutHex (I:Integer);
      BEGIN
      Write (Afile, HexDigits[(I MOD 16) + 1]);
      END;

   FUNCTION BitsToInt(First,Len:Integer):Integer;
      VAR I, Sum: Integer;
      BEGIN
      Sum := 0;
      FOR I := First TO First + Len - 1 DO Sum := Sum+Sum + Bin.Mantissa[I];
      BitsToInt := Sum;
      END;

   BEGIN
   I := 1; IF C.Len < strglgth THEN C.Chars[C.Len + 1] := ' ';
   WHILE C.Chars[I] = ' ' DO I := I + 1;
   Negative := C.Chars[I] = '-';
   IF Negative OR (C.Chars[I] = '+') THEN I := I + 1;
   WHILE C.Chars[I] = '0' DO I := I + 1;
   J := 1;
   GetDigits;
   Dec.Exponent := J - 2;
   IF C.Chars[I] = '.' THEN
      BEGIN
      I := I + 1;
      IF J = 1 THEN WHILE C.Chars[I] = '0' DO
	 BEGIN I:= I + 1; Dec.Exponent := Dec.Exponent - 1; END;
      GetDigits;
      END;
   WHILE J <= MaxDecDigits DO BEGIN Dec.Mantissa[J] := 0; J := J + 1; END;
   IF (C.Chars[I] = 'E') OR (C.Chars[I] = 'e') THEN
      BEGIN
      I := I + 1;
      NegExp := C.Chars[I] = '-';
      IF NegExp OR (C.Chars[I] = '+') THEN I := I + 1;
      J := 0;
      WHILE (C.Chars[I] >= '0') AND (C.Chars[I] <= '9') DO
         BEGIN J := 10*J + Ord(C.Chars[I]) - Ord('0'); I := I + 1; END;
      IF NegExp THEN J := - J;
      Dec.Exponent := Dec.Exponent + J;
      END;
   IF Dec.Mantissa[1] = 0 THEN Dec.Exponent := MaxNegExp;

write('<real:Dec:',Dec.Exponent:1,'E*',Dec.Mantissa[1]:1,'.');
FOR I:=2 TO MaxDecDigits DO BEGIN j:=Dec.Mantissa[i];
  if (j<0) or (j>9) then write('{',j:1,'}') else write(j:1) end;

   IF NOT PowersOk THEN BEGIN InitDec; PowersOk := True; END;
   (* First convert decimal float to binary float *)
   Sign := 1; BitPos := 0; I := MaxPosExp;
   Bin.Exponent := MaxNegExp - 1;
   IF Double THEN J := MaxBinDigits ELSE J := MaxBinSingle;
   Sign := SubtractDec (Dec, TwoToThe[MaxExpPlus1]);
   IF Sign >= 0 THEN UgenError('Real overflow', Novalue);
   WHILE (Sign <> 0) AND (BitPos < J) AND (I >= LeastBit) DO
      BEGIN
      Sign := SubtractDec (Dec, TwoToThe[I]);
      IF (BitPos > 0) OR (Sign >= 0) THEN
         BEGIN
         IF BitPos = 0 THEN Bin.Exponent := I;
	 BitPos := BitPos + 1;
         Bin.Mantissa[BitPos] := Ord (Sign >= 0);
	 END;
      I := I - 1;
      END;
   WHILE BitPos < MaxBinDigits DO
      BEGIN BitPos := BitPos + 1; Bin.Mantissa[BitPos] := 0; END;

write('=Bin:',Bin.Exponent:1,'E*',Bin.Mantissa[1]:1,'.');
FOR I:=2 TO MaxBinDigits DO BEGIN j:=Bin.Mantissa[i];
  if (j<0) or (j>1) then write('{',j:1,'}') else write(j:1) end;write('>');

   (* Then write out the BinaryFloat *)
   IF Bin.Exponent < MaxNegExp THEN
      BEGIN Write (Afile, '#0'); IF Double THEN Write (Afile,',#0'); END
   ELSE
      BEGIN
      I := Bin.Exponent + MaxExpPlus1 + 1;
      (* Add 1 extra because binary point BEFORE most significant bit *)
      IF Negative THEN I := I + 2*MaxExpPlus1;
      Write(Afile, '#/');
      Puthex (I DIV 32); PutHex (I DIV 2);
      Bin.Mantissa[1] := I MOD 2;
      I := 1;
      WHILE I < 25 DO BEGIN PutHex(BitsToInt(I, 4)); I := I + 4; END;
      IF Double THEN
         BEGIN
         Write (Afile, ',#/');
	 WHILE I < 57 DO BEGIN PutHex(BitsToInt(I, 4)); I := I + 4; END;
         END;
      END;
   END;
      
PROCEDURE Putoutvar {(Cval: Valu; Ctyp: Consttype; Reps: Integer)};

   (* Writes a constant to the assembler file, repeated REPS times. *)

   CONST
      Funnychar = ''''; (* character used to delimit string *)
   VAR
      I,J: Integer;

   BEGIN
   FOR J := 1 TO Reps DO
      BEGIN
      (* write out one instance of the initial value *)
      WITH Cval DO
       CASE Ctyp OF
         Nilconst:
	    Write (Afile,'	.long	-1');
         Intconst:
            Write (Afile, '	.long	', Ival:1);
         Realconst,Longrealconst:
	    BEGIN
	    Write (Afile, '	.long	');
	    WriteReal (Cval, Ctyp = Longrealconst);
	    END;
         Packedconst:
	    UgenError ('Illegal INIT data type        ',Novalue);
         Setconst:
	    BEGIN
	    Write (Afile, '	.byte	');
	    (* Put Out The Digits In The Set *)
	    I := 0;	(* Number of hex digits written *)
	    WHILE I < Len DO
   	       BEGIN
   	       IF (I MOD 24 = 0) AND (I > 0) THEN
	          BEGIN Writeln(Afile); Write (Afile, '	.byte	'); END;
   	       IF I mod 2 = 0 THEN Write(Afile, '/');
	       I := I + 1;
	       Write(Afile, Chars[I]);
	       IF (I mod 2 = 0) THEN
	          IF (I mod 24 <> 0) AND (I < Len) THEN Write(Afile,',');
	       END;
	    IF Len mod 2 > 0 THEN Write(Afile, '0');
	    Writeln (Afile); Write (Afile, '	.even');
	    END;
         Stringconst,Ascizconst:
	    BEGIN
	    IF Ctyp = Stringconst THEN Write (Afile, '	.ascii	')
	    ELSE Write (Afile, '	.asciz  ');
	    Write (Afile, Funnychar);
	    FOR I := 1 TO Len DO
	       BEGIN
	       IF Chars[I] = Funnychar THEN Write (Afile, '\');
	       Write (Afile, Chars[I]);
	       END;
	    Writeln (Afile, Funnychar);
	    Write (Afile, '	.even');
	    END;
         END (* case *);
      Writeln (Afile);
      END;
   END;

PROCEDURE WritAt (VAR Atkn: Addrtoken);

   VAR I: Integer;

(* Writatkn outputs the Operand described in ATKN in a proper target machine
  format*)

   Procedure Writeaddress;

      VAR Haslabel: Boolean;

      BEGIN
      WITH Atkn DO 
	 BEGIN 
	 LabTrans (Labfield);
	 Haslabel := Labfield[1] <> ' ';
	 IF Haslabel THEN Write (Afile, Labfield:Lblen(Labfield));
	 IF (Displ <> 0) OR NOT Haslabel THEN
	    BEGIN
	    IF Haslabel AND (Displ > 0) THEN Write (Afile,'+');
	    Write (Afile, Displ:1);
	    END;
	 END;
      END;


   BEGIN
   WITH Atkn DO CASE Form OF

      K:      
	 CASE Ctype OF
            Addrconst:	Write (Afile,'#',Displ:1);
	    Stringconst,longrealconst,Longintconst:
               UgenError ('Illegal immediate constant.   ',Ord(Ctype));
	    Notconst:
               UgenError ('Trying to write null constant.',Novalue);
	    Realconst: WriteReal (Cstring, False);
            Nilconst:	Write(Afile,'#0');
	    Packedconst:Write(Afile,'#',Displ:1,',,',Displ:1,'');
	    Intconst:   Write(Afile,'#',Displ:1);
	    Hexconst:	BEGIN Write(Afile,'#/'); WritHex(Displ); END;
	    Setconst:   WITH Cstring DO
			   BEGIN
			   Write(Afile,'#/');
			   FOR I := 1 TO Len DO
			      Write (Afile, Chars[I]);
			   END;
	    END;
      R:
	 BEGIN
	 Write (Afile,Regname[Reg]);
	 END;

      RI:
	 BEGIN
	 Write (Afile,Regname[Reg], '@');
	 END;

      RIDec:
	 BEGIN
	 Write (Afile,Regname[Reg], '@-');
	 END;

      RIInc:
	 BEGIN
	 Write (Afile,Regname[Reg], '@+');
	 END;

      RIR:
	 BEGIN
	 Write (Afile,Regname[Reg], '@(', displ:1, ',', Regname[Reg2], ':L)');
	 END;

      L:
	 BEGIN
	 IF Context = Literal THEN Write (Afile, '#');
	 Writeaddress;
	 END;

      DR:
	 BEGIN
	 Write (Afile,Regname[Reg],'@(',Displ:1,')');
	 END;

      Empty: Write (Afile,'<<Empty Address Token>>');

      END; (* case Form *)

   END; (* WritAt *)


(* WritInst WritLoc *)

PROCEDURE WritInst (Iptr: Instptr);

   BEGIN
   (* Output One Instruction *)
   WITH Iptr^ DO
      BEGIN
      IF Format = Fakeop THEN
	 UgenError ('Writing fake op.              ',Novalue)
      ELSE
	 BEGIN
         Write (Afile, Indent, Mnems[Op]);
         IF Format <> OP0 THEN WritAt (Od2);
         IF (* (Op <> Sjmp) AND (Op <> Jmpa)*) (Format > OP1) THEN 
	    BEGIN
            Write (Afile, ','); WritAt (Od1);
	    END;
	 Writeln (Afile);
         END;
      END;
   END;

PROCEDURE Printline (Line, Page: Integer);

   Label 99;

   BEGIN
   WHILE Page > Spage DO
      BEGIN
      While not Eopage (Source) DO
	 BEGIN
         Readln (Source);
	 IF Eof(Source) THEN GOTO 99;
         END;
      Spage := Spage + 1;
      Get (Source);
      Sline := 1;
      END;
   WHILE (Line > Sline) DO
      BEGIN
      Readln (Source);
      IF Eopage (Source) OR Eof (Source) THEN Goto 99;
      Sline := Sline + 1;
      END;
   WHILE NOT Eoln (Source) DO
      BEGIN
      Write (Afile, Source^);
      Get (Source);
      END;
   99:
   END;

PROCEDURE WritLoc (Iptr: Instptr);
   BEGIN
   WITH Iptr^.Od1 DO
      IF Size = 0 THEN
	 BEGIN
         Writeln (Afile);
         Write (Afile, AsmComment, Displ:4, '	');
	 IF Spage > 0 THEN
	    IF Displ <> Sline THEN
	       Printline (Displ, 1);
	 Writeln (Afile);
         END;
   END;

PROCEDURE Peephole (Msize, Maxtmp: Integer);
   
   TYPE
      Namerecptr = ^Namerec;
      Namerec = 
         RECORD
	 Lb: Labl;
         Next: Namerecptr;
	 END;
   VAR
      Iptr: Instptr;
      Extnames: Namerecptr;
      Eptr: Namerecptr;

   PROCEDURE Fixit (VAR Od: AddrToken);
      BEGIN
      WITH Od DO
	 IF Fixup = Ftemps THEN Displ := Displ - Msize - Maxtmp
	 ELSE IF Fixup = FFramesize THEN Displ := Displ + Msize + Maxtmp
	 ELSE IF Fixup = FNegFramesize THEN Displ := Displ - Msize - Maxtmp;
      END;
	    
   PROCEDURE Addextlab (VAR Lb: Labl);
      Label 99;
      VAR Eptr: Namerecptr;
      BEGIN
      IF Lb[Labcharsp1] = ' ' THEN GOTO 99;
      Eptr := Extnames;
      WHILE Eptr <> NIL DO
         BEGIN
         IF Eptr^.Lb = Lb THEN GOTO 99;
         Eptr := Eptr^.Next;
         END;
      New (Eptr);
      Eptr^.Lb := Lb;
      Eptr^.Next := Extnames;
      Extnames := Eptr;
      99:
      END;

   BEGIN
   UgenMsg ('Starting peephole.  Msize=    ', Msize);
   UgenMsg ('Maxtmp=                       ', Maxtmp);
   Iptr := Codehead^.Next;
   Extnames := NIL;
   WHILE Iptr <> NIL DO
      BEGIN
      WITH Iptr^ DO
	 BEGIN
(*         IF (Op = addql) OR (Op = subql) THEN
	    IF ((Next^.Op >= SkpGtrS) AND (Next^.Op <= SkpLeqS)) OR
               ((Next^.Op >= JmpzGtrS) AND (Next^.Op <= JmpzLeqS)) THEN
	       IF EquAt (Od1, Od2) THEN
		  IF EquAt (Od1, Next^.Od1) THEN
	             BEGIN
		     Next^.Op := IncOps [Next^.Op, Op = addql];
		     Op := Pnop;
		     Format := Fakeop;
		     END;
*)
	 IF Format <> Fakeop THEN
	    BEGIN
	    IF Od1.Fixup <> Fnone THEN Fixit (Od1);
	    IF Od2.Fixup <> Fnone THEN Fixit (Od2);
	    Addextlab (Od1.Labfield);
	    Addextlab (Od2.Labfield);
            END;
         END;
      Iptr := Iptr^.Next;
      END;
   IF (NOT Is68000) AND (Extnames <> NIL) THEN
      BEGIN
      Eptr := Extnames;
      Write (Afile, ' External ');
      REPEAT
         IF Eptr <> Extnames THEN Write (Afile,',');
         Write (Afile, Eptr^.Lb:Lblen(Eptr^.Lb));
	 Eptr := Eptr^.Next;
      UNTIL Eptr = NIL;
      Writeln (Afile);
      END;
   END;

PROCEDURE WriteLocTable;
   VAR
      Iptr: Instptr;
   BEGIN
   Writeln (Afile, AsmComment, ' LOC table');
   Iptr := Codehead^.Next;
   WHILE Iptr <> NIL DO
      BEGIN
      IF Iptr^.Op = Ploc THEN
	 WITH Iptr^ DO
	    IF Next^.Op <> Plab THEN
	       BEGIN
	       UgenError ('Missing LOC label.            ',Od1.Displ);
	       Iptr := NIL;
	       END
	    ELSE
	       BEGIN
	       Writeln (Afile, ' ',Od1.Displ:1,',,',Od1.Displ:1);
	       Writeln (Afile, Next^.Od1.Labfield);
	       END;
      Iptr := Iptr^.Next;
      IF Iptr <> NIL THEN
         Dispose (Iptr^.Last);
      END;
   Writeln (Afile, ' -1');
   END;

PROCEDURE Relcode;
   VAR
      Iptr: Instptr;
   BEGIN
   Iptr := Codehead^.Next;
   WHILE Iptr <> NIL DO
      BEGIN
      Iptr := Iptr^.Next;
      IF Iptr <> NIL THEN
         Dispose (Iptr^.Last);
      END;
   END;

PROCEDURE WriteProc {(VAR Dbginfo: Dbginforec; Msize, Maxtmp: Integer)};

   (* Writes out the entire procedure. *)
   VAR Timer: Integer;
       Iptr: Instptr;
       Locctr: Integer;
   BEGIN
   IF Tcode THEN 
      BEGIN
      Resetsource (Sourcename);
      Page (Afile);
      Writeln (Afile, AsmComment,Dbginfo.CurProcname);
      Writeln (Afile);
      END;
   Peephole (Msize, Maxtmp);
   Timer := Curtime;
   WITH Dbginfo DO
      BEGIN
      Writeln (Afile);
(*      IF Curpiblab[1] = ' ' THEN Writeln (Afile, Indent, '-1')
      ELSE Writeln (Afile, Indent, Curpiblab, ' ;ptr to PIB'); *)
      LabTrans (Curproclabl);
      Writeln (Afile, '	.globl	',Curproclabl);
      Writeln (Afile, Curproclabl:Lblen(Curproclabl), ':');
      END;
   Locctr := 0;
   Iptr := Codehead^.Next;
   WHILE Iptr <> NIL DO
      BEGIN
      IF Iptr^.Format = Fakeop THEN
         WITH Iptr^ DO
            BEGIN
	    LabTrans (Od1.Labfield);
            IF Op = Plab THEN Writeln (Afile, Od1.Labfield:Lblen(Od1.Labfield), ':')
	    ELSE IF Op = Ploc THEN Writloc (Iptr);
            END
      ELSE Writinst (Iptr);
      Iptr := Iptr^.Next;
      END;
   Instrcnt := Instrcnt + Locctr + 1;
   DumpConstArea;
   IF Dbginfo.Debug OR Dbginfo.Profile THEN
      BEGIN
      Writprocinfoblock (Dbginfo, CurrPage, Currline, Locctr);
      Writeloctable;
      END
   ELSE Relcode;
   Writetime := Writetime + (Curtime - Timer);
   END;

(* CODE BUILDING: Emit3 Emit2 Emitlab Emitloc Addlabelloc *)

PROCEDURE Emit3 {(Opc: Ocode; ResAt, At1, At2: AddrToken)};

   BEGIN
   Ugenerror('Illegal call of Emit3.', Ord(Opc));
   Opc := pillegal; (* Force crash *)
   END;

PROCEDURE Emit0 {(Opc: Ocode)};

   BEGIN
   New (Codetail^.Next);
   Codetail^.Next^.Last := Codetail;
   Codetail := Codetail^.Next;
   WITH Codetail^ DO
      BEGIN
      Next := NIL;
      Op := Opc;
      (* For now, only TOP needs to be distinguished. *)
      Format := Op0;
      IF Op = Pillegal THEN
	 UgenError ('[E0]Couldn"t find instruction.', Novalue);
      END;
   IF Tcode THEN 
      BEGIN
      Write (Afile, AsmComment);
      WritInst (Codetail);
      END;
   END;

PROCEDURE Emit1 {(Opc: Ocode; At1: Addrtoken)};

   BEGIN
   New (Codetail^.Next);
   Codetail^.Next^.Last := Codetail;
   Codetail := Codetail^.Next;
   WITH Codetail^ DO
      BEGIN
      Next := NIL;
      Op := Opc;
      (* For now, only TOP needs to be distinguished. *)
      Format := Op1;
      Od2 := At1;
      IF Op = Pillegal THEN
	 UgenError ('[E1]Couldn"t find instruction.', Novalue);
      END;
   IF Tcode THEN 
      BEGIN
      Write (Afile, AsmComment);
      WritInst (Codetail);
      END;
   END;

PROCEDURE Emit2 {(Opc: Ocode; At1, At2: Addrtoken)};

   BEGIN
   New (Codetail^.Next);
   Codetail^.Next^.Last := Codetail;
   Codetail := Codetail^.Next;
   WITH Codetail^ DO
      BEGIN
      Next := NIL;
      Op := Opc;
      (* For now, only TOP needs to be distinguished. *)
      Format := Xop; 
      Od1 := At1;
      Od2 := At2;
      IF Op = Pillegal THEN
	 UgenError ('[E2]Couldn"t find instruction.', Novalue);
      END;
   IF Tcode THEN 
      BEGIN
      Write (Afile, AsmComment);
      WritInst (Codetail);
      END;
   END;

PROCEDURE Insert {(Opc: Ocode; At1, At2: Addrtoken; After: Integer)};
   (* Insert an extra instruction after After'th current instruction *)

   VAR Tptr,Newptr: Instptr;

   BEGIN
   Tptr := Codehead;
   WHILE After > 0 DO
      BEGIN Tptr := Tptr^.Next; After := After - 1; END;
   New (Newptr);
   Tptr^.Next^.Last := Newptr;
   Newptr^.Next := Tptr^.Next;
   Tptr^.Next := Newptr;
   Newptr^.Last := Tptr;
   WITH Newptr^ DO
      BEGIN
      Op := Opc;
      (* For now, only TOP needs to be distinguished. *)
      Format := Xop; 
      Od1 := At1;
      Od2 := At2;
      END;
   IF Tcode THEN 
      BEGIN
      Write (Afile, AsmComment);
      WritInst (Codetail);
      END;
   END;

PROCEDURE EmitLab {(Lbl: Labl)};

   BEGIN
   New (Codetail^.Next);
   Codetail^.Next^.Last := Codetail;
   Codetail := Codetail^.Next;
   WITH Codetail^ DO
      BEGIN
      Next := NIL;
      Op := Plab;
      Format := Fakeop;
      Od1.Labfield := Lbl;
      END;
   IF Tcode THEN Writeln (Afile, AsmComment, Lbl, ':');
   END;

PROCEDURE EmitLoc {(Page, Line: Integer)};
(* Emits a fake LOC instruction. *)
   BEGIN
   New (Codetail^.Next);
   Codetail^.Next^.Last := Codetail;
   Codetail := Codetail^.Next;
   WITH Codetail^ DO
      BEGIN
      Next := NIL;
      Op := Ploc;
      Format := Fakeop;
      Od1.Displ := Page;
      Od1.Displ := Line;
      Od1.Size := 0;
      END;
   CurrPage := Page;
   Currline := Line;
   IF Tcode THEN
      Writloc (Codetail);
   END;

PROCEDURE Addlabelloc {(Code: Integer;  Ulbl: Labl)};
(* Emits a fake LOC instruction. *)
   BEGIN
   New (Codetail^.Next);
   Codetail^.Next^.Last := Codetail;
   Codetail := Codetail^.Next;
   WITH Codetail^ DO
      BEGIN
      Next := NIL;
      Op := Ploc;
      Format := Fakeop;
      Od1.Labfield := Ulbl;
      Od1.Size := Code;
      END;
   END;

(* InitCd Newcode *)

PROCEDURE Initcd {(Objname: Filename)};

   BEGIN
   (*%ift HedrickPascal*)
{   Rewrite (Output, 'Tty:');}
   (*%endc*)

   Spage := 0;
   Rewrite (Afile, Objname);
   LoadOpnameTable;
(*   LoadIncTable;*)
   Writetime := 0;
   Instrcnt := 0;
   Tcode := False;

   Regname [-1] := 'NL';
   Regname [0]  := 'd0';
   Regname [1]  := 'd1';
   Regname [2]  := 'd2';
   Regname [3]  := 'd3';
   Regname [4]  := 'd4';
   Regname [5]  := 'd5';
   Regname [6]  := 'd6';
   Regname [7]  := 'd7';
   Regname [8]  := 'a0';
   Regname [9]  := 'a1';
   Regname [10] := 'a2';
   Regname [11] := 'a3';
   Regname [12] := 'a4';
   Regname [13] := 'a5';
   Regname [14] := 'a6';
   Regname [15] := 'sp';

   HexDigits := '0123456789ABCDEF';
   PowersOk := False;
   END;

PROCEDURE NewCode {(VAR Dbginfo: Dbginforec)};
   BEGIN
   New (Codehead);
   Codehead^.Format := Fakeop;
   Codehead^.Op := Pstart;
   Codetail := Codehead;
   (* write name of proc to file *)
(*   Page (Afile); *)
   Writeln (Afile, AsmComment,Dbginfo.CurProcname);
   Writeln (Afile);
(*   Writeln (Afile, 'Codehead=',ord(Codehead):1); *)
   END
 
(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

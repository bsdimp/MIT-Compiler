(************************************************************************
 *                                                                      *
 *      (C) COPYRIGHT 1981                                              *
 *      BOARD OF TRUSTEES                                               *
 *      LELAND STANFORD JUNIOR UNIVERSITY                               *
 *      STANFORD, CA. 94305, U. S. A.                                   *
 *                                                                      *
 *      This program may be freely duplicated and distributed           *
 *      provided the copyright notice is retained.                      *
 *                                                                      *
 *      This work was performed as part of the programming language     *
 *      and compiler development at Stanford University for the S-1     *
 *      computer, under subcontracts from the Lawrence Livermore        *
 *      Laboratory to the Computer Science Department, Principal        *
 *      Investigators Profs. Gio Wiederhold and John Hennessy.  The     *
 *      development of the S-1 computer at Livermore is funded by       *
 *      the Office of Naval Research of the U.S.  Navy and the          *
 *      Department of Energy.                                           *
 *                                                                      *
 ************************************************************************)

(*****************************************************************************
 *                                                                           *
 *      UCODE WRITING MODULE                                                 *
 *                                                                           *
 * U-code is a stack-based intermediate  language.  It comes in two forms:   *
 * text representation,  and a binary  representation  (B-code). This module *
 * contains routines for writing both U-code and B-code.                     *
 *                                                                           *
 * Each instruction, whether in U-code or B-code form, is passed in the      *
 * form of a B-code  record, called U. To find out where each value  of      *
 * an instruction  is in  the record,  you should look  at the  the  operand *
 * initialization code in INITUWRITE  this initializes the operand table,    *
 * which describes  the  type and  order  of  the operands  for  each U-code *
 * instruction).  For  example, the  ISTR  instruction has  operands  SDTYPE *
 * SOFFSET, and  SLENGTH, and the  three operands for the  instruction would *
 * be found  in  U.DTYPE, U.OFFSET, and U.LENGTH.                            *
 *                                                                           *
 *  Some exceptions:                                                         *
 *     SPNAME0 and SPNAME1 are both stored in U.PNAME.  The 0 and 1 indicate *
 *       whether then name should appear before or after the Opcode.         *
 *       Similarly, SVNAME0 and SVNAME1 are stored in U.VNAME.               *
 *     SLABEL0, SLABEL1, and SBLOCKNO  are all stored in U.I1.               *
 *    For SCOMMENT, the comment is stored as a string constant in U.CONSTVAL *
 *                                                                           *
 * Since a B-code record is variable in length, depending on the instruction *
 * it  is   alternately  represented   as  an   array  of   integers.   This *
 * representation is used when  reading or writing to  a file.  A routine is *
 * provided to calculate the length of each instruction.  Since instructions *
 * which include  a  constant,  such  as LDC,  may  have  different  lengths *
 * depending on the constant,the length of the constant must be added to the *
 * length of the record being read or written for those instructions.        *
 *                                                                           *
 *****************************************************************************)

(* Host compiler: *)
  (*%Set? HedrickPascal F *)
  (*%Set? UnixPascal T *)

(*%iff UnixPascal*)
{  (*$M-*)}
{}
{  PROGRAM Uwri;}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Uini.Imp';}
(*%else*)
#include "ucode.h";
#include "uini.h";
#include "uwri.h";
(*%endc*)

CONST

  (*%ift HedrickPascal*)
{  Hostcharsperword = 5;    (* characters per word (in packed array of char) *)}
  (*%else*)
  Hostcharsperword = 4;   (* characters per word (in packed array of char) *)
  (*%endc*)


VAR

  Uout: Text;
  Bout: File of Integer;
  Bnayme: Filename;

  Utabr: Utabrec;

  Dtyname: PACKED ARRAY[Datatype] OF Char;  (*printable image of the ucode 
                                             data types*)
  Mtyname: PACKED ARRAY[Memtype] OF Char;   (*printable image ff the ucode 
                                              memory types*)
  Writebc: Boolean;
  Printuc: Boolean;


(* exported procedures *)

(*%iff UnixPascal*)
{}
{PROCEDURE Inituwrite (Var Unam, Bnam: Filename);}
{   FORWARD;}
{}
{FUNCTION Idlen (VAR Id: Identname): Integer;}
{   FORWARD;}
{}
{PROCEDURE Uwrite (U: Bcrec);}
{   FORWARD;}
{}
{FUNCTION Getdtyname (Dtyp: Datatype): Char;}
{   FORWARD;}
{}
{FUNCTION Getmtyname (Mtyp: Memtype): Char;}
{   FORWARD;}
{}
{PROCEDURE Writebuf (VAR Buf: Sourceline; Ctr: Integer);}
{   FORWARD;}
{}
{Procedure Ucoid (Tag:Identname);}
{   FORWARD;}
{}
{Procedure Ucofname (Fnam:Filename);}
{   FORWARD;}
{}
{Procedure Writeoptn (Fname: Identname; Fint: Integer);}
{   FORWARD;}
{}
{PROCEDURE EmitBcode;}
{   FORWARD;}
{}
{PROCEDURE StopUcode;}
{   FORWARD;}
{}
(*%endc*)


(*inituwrite,idlen,fnamelen*)

PROCEDURE Inituwrite {(Var Unam, Bnam: Filename)};
  (* initializes tables used for writing U-code *)
  BEGIN
  Uini;
  Writebc := False;
  Printuc := True;
  Bnayme := Bnam;
  Rewrite (Uout, Unam);
  Dtyname[Zdt] := 'Z';
  Dtyname[Adt] := 'A'; Dtyname[Bdt] := 'B'; Dtyname[Cdt] := 'C'; 
  Dtyname[Edt] := 'E'; Dtyname[Idt] := 'I'; Dtyname[Jdt] := 'J'; 
  Dtyname[Ldt] := 'L'; Dtyname[Mdt] := 'M'; 
  Dtyname[Pdt] := 'P'; Dtyname[Qdt] := 'Q'; Dtyname[Rdt] := 'R'; 
  Dtyname[Sdt] := 'S';

  Mtyname[Zmt] := 'Z'; Mtyname[Mmt] := 'M'; Mtyname[Fmt] := 'F'; 
  Mtyname[Rmt] := 'R'; Mtyname[Smt] := 'S'; Mtyname[Pmt] := 'P';
  
  END;

FUNCTION Idlen {(VAR Id: Identname): Integer};
     (* returns the length of the identifier, not counting trailing spaces *)
     Label 99;

     VAR I: Integer;

     BEGIN
     FOR I := Identlength DOWNTO 1 DO
        IF Id[I] <> ' ' THEN GOTO 99;
     99: Idlen := I;
     END;

   FUNCTION Fnamelen (VAR F: Filename): Integer;
     (* returns the length of the identifier, not counting trailing spaces *)
     Label 99;

     VAR I: Integer;

     BEGIN
     FOR I := Filenamelen DOWNTO 1 DO
        IF F[I] <> ' ' THEN GOTO 99;
     99: Fnamelen := I;
     END;


PROCEDURE Bwrite (VAR U: Bcrec);
   (* Write the global record U to the binary file Bcode *)
   VAR
      Llen: Integer;
      Index:Integer;
   BEGIN
   WITH U DO
      BEGIN
      Getutabrec (Opc, Utabr);
      FOR Index := 1 TO Utabr.Instlength DO
         BEGIN
         Bout^ := U.Intarray[Index];
         Put(Bout);
         END;
      IF Utabr.Hasconst THEN
         BEGIN
         Llen := 1;
         IF (Opc <> Uchkl) AND (Opc <> Uchkh) AND
            (U.Dtype IN [Idt,Rdt,Qdt,Sdt,Mdt]) THEN
            BEGIN
            IF Opc = Uinit THEN
               BEGIN
               Llen := Llen +
               (Initval.Len + Hostcharsperword-1) DIV Hostcharsperword
               END
            ELSE
               BEGIN
               Llen := Llen +
               (Constval.Len + Hostcharsperword-1) DIV Hostcharsperword;
               END;
            Bout^ := Llen; Put(Bout);
            END;
         FOR Index := Utabr.Instlength+1 TO Utabr.Instlength + Llen DO
            BEGIN
            Bout^ := U.Intarray[Index]; Put(Bout);
            END;
         END;
      END;
   END;


PROCEDURE Putconst(Konsttyp:Datatype; Fvalu: Valu);

   (* Finishes a Ucode instruction that gives the value of a constant *)

   VAR
      I:Integer;

   BEGIN
   Write (Uout,' ');
   WITH Fvalu DO
      CASE Konsttyp OF
         Cdt:
            BEGIN
            Write(Uout,'''',Chr(Ival),'''');
            IF Chr(Ival) = '''' THEN
               Write(Uout,'''');
            END;
         Adt,Bdt,Jdt,Ldt:
            Write(Uout,Ival:1);
         Mdt:
            BEGIN
            Write(Uout,'''');
            FOR I := 1 TO Len DO
               BEGIN
               Write(Uout,Chars[I]);
               IF Chars[I] = '''' THEN
                  Write(Uout,'''');
               END;
            Write(Uout,'''');
            END;
         Qdt,Rdt,Sdt:
            FOR I := 1 TO Len DO
               Write(Uout,Chars[I]);
         END (*CASE*);

   END;


PROCEDURE Uwrite {(U: Bcrec)};

   (* Write out the U-code instruction that is in the record U *)
   VAR
      Thisformat: Uops;
      I,J:Integer;

   BEGIN
   IF Printuc THEN
      IF Writebc THEN Bwrite (U)
      ELSE WITH U DO
         BEGIN
         Getutabrec (Opc, Utabr);
         Thisformat := Utabr.Format;
         IF Thisformat[1] IN [Slabel0,Spname0,Svname0] THEN
            CASE Thisformat[1] OF
               Slabel0:   Write (Uout,'L',I1:1);
               Spname0:   Write(Uout,Pname:Idlen(Pname));
               Svname0:   Write(Uout,Vname:Idlen(Vname))
                  END;
         Write(Uout,' ');
         Getutabrec (Opc, Utabr);
         Write (Uout,Utabr.Opcname);
         I := 1;
         WHILE I <> 99 DO
            BEGIN
            CASE Thisformat[I] OF
               Send:       I := 98;
               Sdtype:     Write (Uout,' ',Dtyname[Dtype]);
               Smtype:     Write (Uout,' ',Mtyname[Mtype]);
               Slexlev:    Write (Uout,' ',Lexlev:1);
               Slabel0:    ;
               Slabel1:    Write (Uout,' L',I1:1);
               Sblockno:   Write (Uout,' ',I1:1);
               Sdtype2:    Write (Uout,' ',Dtyname[Dtype2]);
               Spname1:    Write (Uout,' ',Pname:Idlen(Pname));
               Spname0:    ;
               Spop:       Write (Uout,' ',Pop:1);
               Spush:      Write (Uout,' ',Push:1);
               Sexternal:  Write (Uout,' ',Extrnal:1);
               Slength:    Write (Uout,' ',Length:1);
               Sconstval:  Putconst(Dtype,Constval);
               Soffset:    Write (Uout,' ',Offset:1);
               Svname0:    ;
               Svname1:    Write (Uout,' ',Vname:Idlen(Vname));
               Soffset2:   Write (Uout,' ',Offset2:1);
               Sinitval:   Putconst(Dtype,Initval);
               Slabel2:    Write (Uout,' L',Label2:1);
               Scomment:
                  BEGIN
                  Write (Uout,' ');
                  FOR J := 1 TO Constval.Len DO 
                     Write (Uout,Constval.Chars[J]);
                  END;
            END;
            I := I+1;
            END;
         Writeln(Uout);
         END;
   END;


(* getdtyname,getmtyname,writebuf,ucoid *)

FUNCTION Getdtyname {(Dtyp: Datatype): Char};
  BEGIN
  Getdtyname := Dtyname[Dtyp];
  END;

FUNCTION Getmtyname {(Mtyp: Memtype): Char};
  BEGIN
  Getmtyname := Mtyname[Mtyp];
  END;


PROCEDURE Writebuf {(VAR Buf: Sourceline; Ctr: Integer)};

   VAR I: Integer;
       U: Bcrec;
   BEGIN
   IF Writebc THEN
      WITH U.Constval DO
         BEGIN
         FOR I := 1 TO Ctr DO
           Chars[I] := Buf[I];
         Len := Ctr;
         U.Opc := Ucomm;
         U.Dtype := Mdt;
         Uwrite(U);
         END
   ELSE
      Writeln (Uout, ' COMM ',Buf: Ctr);
   END;

Procedure Ucoid {(Tag:Identname)};
   (* Writes a short Ucode comment *)
   VAR I: Integer;
       U: Bcrec;
   BEGIN
   IF Writebc THEN
      WITH U.Constval DO
         BEGIN
         FOR I := 1 TO Identlength DO
           Chars[I] := Tag[I];
         Len := Identlength;
         U.Opc := Ucomm;
         U.Dtype := Mdt;
         Uwrite(U);
         END
   ELSE
      Writeln (Uout, ' COMM ',Tag);
   END;

Procedure Ucofname {(Fnam:Filename)};
   (* Writes a short Ucode comment *)
   VAR I: Integer;
       U: Bcrec;
   BEGIN
   IF Writebc THEN
      WITH U.Constval DO
         BEGIN
	 Len := Fnamelen (Fnam);
         FOR I := 1 TO Len DO
            Chars[I] := Fnam[I];
         U.Opc := Ucomm;
         U.Dtype := Mdt;
         Uwrite(U);
         END
   ELSE
      Writeln (Uout, ' COMM ',Fnam: Fnamelen(Fnam));
   END;


Procedure Writeoptn {(Fname: Identname; Fint: Integer)};

   VAR U: Bcrec;

   BEGIN
   U.Opc := Uoptn;
   U.Pname := Fname;
   U.I1 := Fint;
   Uwrite(U);
   END;

PROCEDURE EmitBcode{};
  (* called when Binary output is desired *)
  BEGIN
  Writeln (Uout, ' OPTN TBCODE 1');
  Ucofname (Bnayme);
  Rewrite (Bout, Bnayme);
  Writebc := true;
  END;

PROCEDURE StopUcode{};
   BEGIN
   Printuc := False;
   Rewrite (Uout);
   Writeln (Uout, ' OPTN TERROR 1');
   If Writebc Then Rewrite (Bout);
   END

(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

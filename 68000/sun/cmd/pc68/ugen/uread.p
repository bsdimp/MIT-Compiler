(******************************************************************************)
(******************************************************************************)
(*                                                                            *)
(*      UCODE READING MODULE                                                  *)
(*                                                                            *)
(* U-code is a stack-based intermediate  language.  It comes in two forms: a  *)
(* text representation,  and a binary  representation (B-code).   This module *)
(* contains routines for writing both U-code and B-code.                      *)
(*                                                                            *)
(* Each instruction, whether in U-code or B-code form, is passed in the       *)
(* form of a B-code  record, called U. To find out where each value  of       *)
(* an instruction  is in  the record,  you  should look  at the  the  operand *)
(* initialization code in INITUWRITE (this initializes the operand table,     *)
(* which describes  the  type and  order  of  the operands  for  each  U-code *)
(* instruction).  For  example, the  ISTR  instruction has  operands  SDTYPE, *)
(* SOFFSET, and  SLENGTH, and the  three operands for the  instruction would  *)
(* be found  in  U.DTYPE, U.OFFSET, and U.LENGTH.                             *)
(*                                                                            *)
(*  Some exceptions:                                                          *)
(*     SPNAME0 and SPNAME1 are both stored in U.PNAME.  The 0 and 1 indicate  *)
(*       whether then name should appear before or after the Opcode.          *)
(*       Similarly, SVNAME0 and SVNAME1 are stored in U.VNAME.                *)
(*     SLABEL0, SLABEL1, and SBLOCKNO  are all stored in U.I1.                *)
(*     For SCOMMENT, the comment is stored as a string constant in U.CONSTVAL.*)
(*                                                                            *)
(* Since a B-code record is variable in length, depending on the instruction, *)
(* it  is   alternately  represented   as  an   array  of   integers.    This *)
(* representation is used when  reading or writing to  a file.  A routine  is *)
(* provided to calculate the length of each instruction.  Since  instructions *)
(* which include  a  constant,  such  as LDC,  may  have  different  lengths, *)
(* depending on the constant, the length of the constant must be added to the *)
(* length of the record being read or written for those instructions.         *)
(******************************************************************************)
(******************************************************************************)


(*-- UREAD.PAS --*)

(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%iff UnixPascal*)
{  (*$M-*)}
{}
{  PROGRAM Uread;}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Uini.Imp';}
(*%else*)
#include "ucode.h";
#include "uini.h";
#include "uread.h";
(*%endc*)

CONST
  Opchtsize = 263;                (* size of Opc hash table*)
  Opchtsizem1 = 262;

TYPE

  Intfile = File of Integer;

  Errorstring = PACKED ARRAY [1 .. 20] OF Char;           (*Mess for Ugenerror*)

VAR

    Utabr: Utabrec;
    Mtyname: ARRAY [Memtype] OF Char;     (*memory type name table.  tells  *)
                                          (* Printnxtinstr proper type char *)
    Dtyname: ARRAY [Datatype] OF Char;    (*data type name table. specifies *)
                                          (* Data character for PRINTNXT..  *)
                                          (* given DATATYPE                 *)
    Dtytype: ARRAY ['A'..'Z'] OF Datatype;(*inverse of dtyname              *)
    Mtytype: ARRAY ['A'..'Z'] OF Memtype; (*inverse of mtytype              *)
    Opchashtab :  ARRAY [0..Opchtsizem1] OF Uopcode; 
                                          (*Hash table for Uopcodes.  Given *)
                                          (* Nmemonic, used in Mnentoopc  *)
                                          (* to determine Uopcode.          *)
    Memorychars,                          (*legal ucode memorytype names    *)
    Datachars: SET OF 'A'..'Z';           (*legal ucode datatype names      *)
    Setconstantchars: SET OF '0'..'H';    (*legal ucode literal set charac. *)

    Bcode: Intfile;              (*Binary ucode file (if any)*)
    Ufile: Text;          	(*Ucode input and target machine output *)
    ReadingBcode: Boolean;	(* True if reading from Bcode file *)

(* exported procedures *)

(*%iff UnixPascal*)
{}
{PROCEDURE SwitchtoBcode (Bname: Filename);}
{   FORWARD;}
{}
{PROCEDURE ReadUinstr (VAR U: Bcrec);}
{   FORWARD;}
{}
{PROCEDURE GetOpcstr (Op: Uopcode; VAR Mnem: Opcstring);}
{   FORWARD;}
{}
{PROCEDURE Initur (Uname: Filename);}
{   FORWARD;}
{}
(*%endc*)
(* UreadError **)

PROCEDURE UreadError (Msg: ErrorString; VAR U:Bcrec); 
(* This routine reports to the tty any errors that occur while reading the
   ucode file*)
   BEGIN
   Writeln (Output);
   Getutabrec (U.Opc, Utabr);
   Writeln (Output,'Error while reading ',Utabr.Opcname,': ');
   Writeln (Output, '   ',Msg);
   END;  

(* Opchash Enteropc Mnemtoopc Ureadinit **)

FUNCTION opchash (VAR mnem :  opcstring) :  integer;
   (* returns hash value of opcode *)
   BEGIN
   opchash := (((ord(mnem[2])*4 + ord(mnem[1]))*8 + ord(mnem[3]))*8
                +ord(mnem[4])*8) MOD opchtsize;
   END;

PROCEDURE enteropc (nam :  opcstring;  opc : uopcode);
   (* enters opcode in table *)
   VAR h : 0..opchtsizem1;
   BEGIN
   h := opchash(nam);
   WHILE opchashtab[h] <> Unop DO
      h := (h + 1) MOD opchtsize;
   opchashtab[h] := opc;
   END;

FUNCTION mnemtoopc (VAR mnem :  opcstring) :  uopcode;
   (* looks up an opcode in the hash table.*)

   VAR h :  integer;
      lopc : uopcode;
      u : bcrec;
   BEGIN
   h := opchash (mnem);
   lopc := opchashtab[h];
   Getutabrec (lopc, Utabr);
   WHILE (Utabr.opcname <> mnem) AND (lopc <> Unop) DO
      BEGIN
      h := (h + 1) MOD opchtsize;
      lopc := opchashtab[h];
      Getutabrec (lopc, Utabr);
      END;
   IF lopc <> Unop THEN
      mnemtoopc := lopc
   ELSE
      BEGIN
      u.opc := Unop;
      Ureaderror('Cannot parse opcode ',U);
      mnemtoopc := Unop;
      END
   END;

(* Uread Getmtype Getdtype Getint Getlint Getname Getreal Getlreal Getset Getstring Getcomment  Getconst Getlab Getfirslabel Labelval Getopc *)

PROCEDURE uread (VAR Ufile: text; VAR U: Bcrec);
   (* read in u-code instruction;  put it in record u *)
   VAR lname:identname;
      thisformat: uops;
      gotone: boolean;
      lvalu:valu;
      i: integer;
      lopc: uopcode;

FUNCTION getmtype: memtype;
   (* skip initial blanks and read a memory type *)
   BEGIN
   getmtype := zmt;
   REPEAT get(ufile) UNTIL ufile^ <> ' ';
   IF ufile^ IN memorychars THEN
      getmtype := mtytype[ufile^]
   ELSE
      BEGIN
      Ureaderror('Invalid memory type ',U);
      U.Opc := Unop;
      END;
   get (ufile);
   END;

FUNCTION getdtype:datatype;
   (* skip initial blanks and read a data type *)
   BEGIN
   getdtype := zdt;
   REPEAT get(ufile) UNTIL ufile^ <> ' ';
   IF ufile^ IN datachars THEN
      getdtype := dtytype[ufile^]
   ELSE
      BEGIN
      Ureaderror('Invalid data type   ',U);
      U.Opc := Unop;
      END;
   get(ufile);
   END;


FUNCTION getint:integer;
   (* skip initial blanks and read an integer *)
   VAR i:integer;
   BEGIN
   WHILE ufile^ = ' ' DO get(ufile);
   IF ((ufile^ < '0') OR (ufile^ > '9')) AND (ufile^ <> '-') THEN
      BEGIN
      Ureaderror('Cannot parse integer',U);
      U.Opc := Unop;
      i := 0;
      END
   ELSE read (ufile,i);
   getint := i;
   END;

PROCEDURE getlint(VAR S : Valu);
   (* skip initial blanks and read a long integer *)
   VAR i:integer;
   BEGIN
   I := 0;
   WHILE ufile^ = ' ' DO get(ufile);
   IF (ufile^ < '0') OR (ufile^ > '9') THEN
      BEGIN
      Ureaderror('Cannot parse integer',U);
      U.opc := Unop;
      i := 0;
      END
   ELSE
      WHILE (Ufile^ <> ' ') DO BEGIN 
         I := Succ(I);
         S.Chars[I] := Ufile^;
         Get (Ufile);
         END;
   S.Len := I;
   END;

PROCEDURE getname (VAR lname: identname);
   (* skip initial blanks and read a naame; pad with blanks *)
   VAR
      i:integer;
   BEGIN
   WHILE ufile^ = ' ' DO get(ufile);
   i := 0;
   lname := Blankid;
   WHILE (ufile^ <> ' ') AND NOT eoln(ufile) DO
      BEGIN
      i := i+1;
      IF i <= identlength THEN lname[i] := ufile^;
      get(ufile);
      END;
   END;


PROCEDURE getreal (VAR s :  valu);

   VAR
      I : Integer;

   BEGIN
   WHILE (ufile^=' ') OR (ufile^=',') DO
      get (ufile);
   I := 0;
   WHILE (Ufile^ <> ' ')  DO BEGIN 
      I := Succ (I);
      S.Chars[I] := Ufile^;
      Get (Ufile);
      END;
   S.Len := I;
   END (*readreal*);

PROCEDURE getlreal (VAR s :  valu);

   VAR
      I : Integer;

   BEGIN
   WHILE (ufile^=' ') OR (ufile^=',') DO
      get (ufile);
   I := 0;
   WHILE (Ufile^ <> ' ')  DO BEGIN 
      I := Succ (I);
      S.Chars[I] := Ufile^;
      Get (Ufile);
      END;
   S.Len := I;
   END (*readreal*);


PROCEDURE getset(VAR s :  valu);

   VAR
      I : Integer;

   BEGIN

        (* Discard Leading Blanks *)
   WHILE Ufile^=' ' DO Get (Ufile);

        (* Read The Set *)
   I := 0;
   WHILE (Ufile^ <> ' ') DO BEGIN 
      I := Succ(I);
      S.Chars[I] := Ufile^;
      Get (Ufile);
      END;
   S.Len := I;

   END;

PROCEDURE getstring(VAR str : valu);
   VAR ch:char;

      (* skip initial blanks and read in a quoted string;
       pairs of single quotes should be treated as a single quote within the 
       string *)
   BEGIN
   REPEAT read(ufile,ch) UNTIL (ch = '''') OR eoln (ufile);
   read(ufile,ch);  (* bypass first quote *)
   WITH str DO
      BEGIN
      Len := 0;
      (* end of string found when single quote (not pair) is found *)
      WHILE (ch<>'''') OR (ufile^='''') DO
         BEGIN
         IF Len < Strglgth THEN Len := Len + 1;
         Chars[Len] := ch;
         IF ch = '''' THEN read (ufile,ch);
         read (ufile,ch);
         END (*while*);
      END;
   END;

PROCEDURE getcomment(VAR str : valu);

   (* puts all characters up to the end of the line in a string constant str *)
   BEGIN
   IF NOT eoln(ufile)THEN get(ufile);
   (* skip the first character after the opcode *)
   WITH str DO
      BEGIN
      Len := 0;
      WHILE NOT eoln(ufile) DO
         BEGIN
         IF Len < Strglgth THEN Len := Len + 1;
         Chars[Len] := ufile^;
         get(ufile);
         END;
      END;
   END (*readstring*);

PROCEDURE getconst(dty:datatype; VAR fvalu: valu; clen:integer);
   (* get a constant of type dty and return in fvalu (length in clen) *)
   VAR lvalu: valu;
   BEGIN
   WITH fvalu DO
      CASE dty OF
         adt,bdt,ldt,jdt : ival := getint;
         cdt:
            BEGIN
            getstring(lvalu);
            IF lvalu.Len <> 1 THEN
               BEGIN
               Ureaderror('Cannot parse char   ',U);
               U.opc := Unop;
               END;
            ival := ord(lvalu.Chars[1]);
            END;
         idt : getlint(fvalu);
         mdt : getstring(fvalu);
         qdt : getlreal(fvalu);
         rdt : getreal(fvalu);
         sdt :
            BEGIN
            getset(fvalu);
            IF (fvalu.Len * Setdigitbits) <> clen THEN
               BEGIN
               Ureaderror('Invalid set length  ',U);
               U.opc := Unop;
               END;
            END;
         END;
   END;

FUNCTION getlab: integer;
   (* skip initial blanks, then read label of from ldd...dd; convert dd...dd
    to integer and return it *)
   VAR i:integer;
      ch: char;
   BEGIN
   REPEAT read(ufile,ch) UNTIL ch <> ' ';
   IF (ch <> 'L') OR (ufile^ < '0') OR (ufile^ > '9') THEN
      BEGIN
      Ureaderror('Invalid label       ',U);
      U.opc := Unop
      END
   ELSE read (ufile,i);
   getlab := i;
   END;

PROCEDURE getfirstlabel (VAR gotone: boolean; VAR lname: identname);
   (* if first character of line is nonblank, get name and return it
    in lname *)
   VAR i:integer;
   BEGIN
   gotone := ufile^ <> ' ';
   IF gotone THEN
      BEGIN
      lname := Blankid;
      i := 0;
      REPEAT
         i := i + 1;
         lname[i] := ufile^;
         get(ufile);
      UNTIL ufile^ = ' ';
      END;
   END;

FUNCTION labelval(lname:identname): integer;
   (* convert label of the form ldd...dd to integer *)
   VAR i,j:integer;
      errorflag: boolean;
      ch:char;
   BEGIN
   errorflag := lname[1] <> 'L';
   i := 0;
   j := 2;
   WHILE NOT errorflag AND (j <= identlength) DO
      BEGIN
      ch := lname[j];
      IF ch = ' ' THEN j := identlength
      ELSE IF (ch < '0') OR (ch > '9') THEN errorflag := true
      ELSE i := i*10 + ord(ch) - ord('0');
      j := j + 1;
      END;
   IF errorflag THEN
      BEGIN
      Ureaderror('Invalid label       ',U);
      U.opc := Unop;
      END;
   labelval := i;
   END;


FUNCTION getopc: uopcode;
   (* skip initial blanks; read opcode name; look it up in hash table and return
      the opcode *)
   VAR
      lopcname: Opcstring;
      i:integer;
   BEGIN
   WHILE ufile^ = ' ' DO get(ufile);
   lopcname := '    ';
   i := 0;
   REPEAT
      i := i + 1;
      lopcname[i] := ufile^;
      get(ufile);
   UNTIL (ufile^ = ' ') OR (i = 4);
writeln('UOp: ', lopcname);
   getopc :=  mnemtoopc(lopcname);
   END;



(* Uread *)
   
   BEGIN
   IF Eof (Ufile) THEN
      U.Opc := Ueof
   ELSE WITH U DO
      BEGIN
      getfirstlabel (gotone, lname);
      lopc:=getopc;
      opc := lopc;
      Getutabrec (lopc, Utabr);
      thisformat:=utabr.format;
      IF (thisformat[1] IN [slabel0,spname0,svname0]) THEN
         BEGIN
         IF NOT gotone THEN
             BEGIN
             U.opc := Unop;
             Ureaderror('Missing label field ',U);
             END
         END
      ELSE IF gotone THEN
         BEGIN
         U.opc := Unop;
         Ureaderror('Extra label field   ',U);
         END;
      i := 1;
      WHILE i <> 99 DO
         BEGIN
         CASE thisformat[i] OF
            send:       i := 98;
            sdtype:     dtype := getdtype;
            smtype:     mtype := getmtype;
            slexlev:    lexlev := getint;
            slabel0:    i1 := labelval (lname);
            slabel1:    i1 := getlab;
            sblockno:   i1 := getint;
            sdtype2:    dtype2 := getdtype;
            spname0:    pname := lname;
               spname1:    BEGIN getname(lname); pname := lname END;
            spop:       pop := getint;
            spush:      push := getint;
            sexternal:  extrnal := getint;
            slength:    length := getint;
            sconstval:
               BEGIN
               getconst(dtype,lvalu,length);
               constval := lvalu
               END;
            sinitval:
               BEGIN
               getconst(dtype,lvalu,length);
               initval := lvalu
               END;
            soffset:    offset := getint;
            svname0:    vname := lname;
               svname1:    BEGIN getname(lname); vname := lname END;
            soffset2:   offset2 := getint;
            slabel2: label2 := getlab;
            scomment:
               BEGIN
               getcomment(lvalu);
               constval := lvalu;
               dtype := mdt;
               END;
            END;
         i := i+1;
         END;
      readln (ufile);
      END;
   END;


(* Bread *)

procedure BREAD (VAR Bcode: Intfile; VAR U: Bcrec);
   (* Read next record from binary file Bcode and put it in U. *)
   var
      Index, Llen: Integer;
   begin
   IF Eof(Bcode) THEN U.Opc := Ueof
   ELSE With U do
      begin
      U.INTARRAY[1] := BCODE^; GET(BCODE);
      Getutabrec (opc, Utabr);
      LLEN := utabr.INSTLENGTH;
      for INDEX := 2 to LLEN do
         begin
         U.INTARRAY[INDEX] := BCODE^; GET(BCODE);
         end;
      if utabr.HASCONST then
         begin
         U.INTARRAY[LLEN+1] := BCODE^; GET(BCODE);
         if (U.DTYPE in [IDT,QDT,RDT,SDT,MDT]) AND 
            (OPC <> UCHKL) and (OPC <> UCHKH) THEN
            for INDEX := 1 to U.INTARRAY[LLEN+1] do
                begin
                U.INTARRAY[LLEN+INDEX] := BCODE^; GET(BCODE);
                end;
         end;
      end;
   end;

PROCEDURE SwitchtoBcode {(Bname: Filename)};
   BEGIN
   Reset (Bcode, Bname);
   ReadingBcode := True;
   END;

PROCEDURE ReadUinstr {(VAR U: Bcrec)};
   BEGIN
   IF Readingbcode THEN Bread (Bcode, U)
   ELSE Uread (Ufile, U);
   END;

PROCEDURE GetOpcstr {(Op: Uopcode; VAR Mnem: Opcstring)};
   BEGIN
   Getutabrec (Op, Utabr);
   Mnem := Utabr.Opcname;
   END;

PROCEDURE Initur {(Uname: Filename)};

   (* initializes opcode hash table, data type table, and memory type table;
    also some sets of characters used for parsing *)

   VAR lopc:uopcode;
      i:integer;
   BEGIN
   (*%ift HedrickPascal*)
{   Rewrite (Output,'Tty:');}
   (*%endc*)

   Readingbcode := False;
   Reset (Ufile, Uname);
   Uini;

   FOR i := 0 TO opchtsizem1 DO
      opchashtab[i] := Unop;
   FOR lopc := uabs TO Pred(Unop) DO
      BEGIN
      Getutabrec (Lopc, Utabr);
      Enteropc (Utabr.opcname, lopc);
      END;

   datachars := ['A','B','C','E','I','J','K','L','M','P','Q','R','S'];
   memorychars := ['M','T','S','R','F','P'];
   IF setdigitbits = 3 THEN
      setconstantchars := ['0','1','2','3','4','5','6','7']
   ELSE
      setconstantchars :=
      ['0','1','2','3','4','5','6','7','8','9','A','B','C','D','E','F'];


   mtytype['Z'] := zmt;
   mtytype['T'] := tmt;
   mtytype['M'] := mmt;
   mtytype['S'] := smt;
   mtytype['R'] := rmt;
   mtytype['F'] := fmt;
   mtytype['P'] := pmt;

   dtytype['A'] := adt;
   dtytype['B'] := bdt;
   dtytype['C'] := cdt;
   dtytype['E'] := edt;
   dtytype['I'] := idt;
   dtytype['J'] := jdt;
   dtytype['L'] := ldt;
   dtytype['M'] := mdt;
   dtytype['P'] := pdt;
   dtytype['Q'] := qdt;
   dtytype['R'] := rdt;
   dtytype['S'] := sdt;

   END
(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

(*#B-,U0,G+*)
module inits;

(* runtimes for pascal programs *)

const
   tabsetting = 8;
   identlength = 16;    (* length of scalar identifiers *)
   maxdigits = 24;   (* max number of digits in integer *)
   underbar = '_';
   stdstringlength = 132;  (* length of all strings within these runtimes *)
   runbufsize = 11;   (* number of words occupied by primitive run-time
 			 buffers, flags, etc. *)
   cape = 69;     (* ord(upper case e)*)
   lowere = 101;    (* ord(lower case e)*)
   (* do not change without changing primitive runtimes!*)

   lowercasea = 97;      (* ord (lower case a) *)
   lowercasez = 122;  (* ord (lower case z) *)
   uplowdif = 32;    (* ord (lower case a) - ord (upper case a) *)
  setunitmax = 31;
  setunitsize = 32;
  setmax = 319;
  setsperset = 10;

type
   errorstring = packed array [1..28] of char;
   alfa = packed array[1..10] of char;
   typeoffile = (binary,charfile,asciifile);
   longinteger = integer;
   digitarray = array[1..maxdigits] of 0..9;
   digitctr = 0..maxdigits;
   stdstring = packed array [1..stdstringlength] of char;
   identifier = packed array [1..identlength] of char;
   chararray = array [1..stdstringlength] of char;
   standardset = set of 0..setmax;

   setsub = 1..setsperset;    (*chd*)
   targetset = array[setsub] of set of 0..setunitmax;  (*used to build a target set*)

   scalarvector = array[0..100] of identifier;
   scalarvptr = ^scalarvector;
   scalarform = (integerform,charform,declaredform);
   filestatus = (notopen,openforinput,openforoutput);
   txtfdb = record
(*	   namelength : 0..stdstringlength;*);
(*	   name : stdstring; *)
	   status : filestatus;
	   device : (anydev,ttydev,leafdev);
	   eofflag : boolean;
	   bufferinvalid : boolean;
	   filetype : typeoffile;
	   ttymode : boolean;  (* true = line at a time input *);
	   channel : integer;
	   prompt: identifier;
	   eolnflag : boolean;
	   eopageflag : boolean;
	   charcount : integer;
	   linecount : integer;
	   pagecount : integer;
	   tabcount : integer;
	   pbuffersize : integer;	(* Size of buffer in bits *)
	   runbufs : array[1..runbufsize] of integer;
	   pbuffer : char;
	    end;
PROCEDURE $Rdc (VAR Ch: Char; VAR Fdb: Txtfdb); EXTERN;
FUNCTION $Bufval (VAR Fdb: Txtfdb):Char; EXTERN;
PROCEDURE $Rdi (VAR i: Integer; VAR Fdb: Txtfdb); EXTERN;
procedure $parseinteger (var fdb:txtfdb; var digits: digitarray;
	 var negative,octal: boolean; var dctr: digitctr); EXTERN;

PROCEDURE $Rdr ( VAR Sourceval:Real; VAR Fdb:Txtfdb );
   VAR Mant: Integer;
      Negative, Octal: Boolean;
      Digits: Digitarray;
      Scale,Exponent,I: Integer;
      Dctr: Digitctr;
      Ch:Char;
      Sign:Boolean;
      Rval,Fac,R:Real;
   BEGIN
   $Parseinteger (Fdb,Digits,Negative,Octal,Dctr);
   Mant := 0;
   FOR I := 1 TO Dctr DO
      Mant := 10*Mant + Digits[I];
   Scale := 0;
   Rval := Mant;
   IF $Bufval(Fdb) = '.' THEN
      BEGIN
      $Rdc (Ch,Fdb);
      WHILE ($Bufval(Fdb) IN ['0'..'9']) DO
	 BEGIN
	 Rval := 10.0 * Rval + (Ord($Bufval(Fdb)) - Ord('0'));
	 Scale := Scale - 1;
	 $Rdc (Ch,Fdb);
	 END;
      END;
   IF Negative THEN Rval := -Rval;
   Ch := $Bufval(Fdb);
   IF (Ch = 'E') OR (Ch = 'e') THEN
      BEGIN
      $Rdc(Ch,Fdb);
      $Rdi (Exponent,Fdb);
      Scale := Scale + Exponent;
      END;
   IF Scale <> 0 THEN
      BEGIN
      IF Scale < 0 THEN
	 BEGIN
	 Scale := Abs(Scale); Fac := 0.1
	 END
      ELSE
	 Fac := 10.0;
      R := 1.0;
      REPEAT
	 IF Odd(Scale) THEN R := R * Fac;
	 Scale := Scale DIV 2;
	 IF Scale <> 0 THEN Fac := Sqr(Fac)
      UNTIL Scale = 0;

      Rval := Rval * R;
      END;
   Sourceval := Rval;
   END;
.

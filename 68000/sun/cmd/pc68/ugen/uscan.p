(* -- USCAN.PAS -- *)

#include 'ucode.h';
#include 'uscan.h';
#include 'exit.h';

CONST
   LcasA = 97;         (* ord (lower case A) *)
   LcasZ = 122;        (* ord (lower case Z) *)
   Casedif = 32;       (* ord (lower case A) - ord (upper case A) *)

PROCEDURE Uexit {(Errors: Boolean)};
   BEGIN
      IF Errors THEN exit(-1) ELSE exit(0);
   END;

PROCEDURE Newext {(VAR Fnam: Filename; Ext: Fileext)};

   (* Finds the current extension in a file name and replaces it with Ext. *)

   VAR F,N,E: Integer;
       Newname: Filename;

   BEGIN
   Newname := Blankfilename;
   (* copy the part preceding the period *)
   F := 1;
   WHILE NOT (Fnam[F] IN ['.',' ']) DO
      BEGIN
      Newname[F] := Fnam[F];
      F := F + 1;
      END;
   (* put in the dot *)
   N := F;
   Newname[N] := '.';
   IF Fnam[F] = '.' THEN 
      BEGIN (* bypass old extension *)
      While Fnam[F] <> ' ' DO
	 F := F + 1;
      END;
   (* copy the extension *)
   FOR E := 1 TO Fileextlen DO
      IF Ext[E] <> ' ' THEN
	 BEGIN
	 N := N+1;
	 Newname[N] := Ext[E];
	 END;
   IF Fnam[F] <> ' ' THEN
      BEGIN
      Writeln (Output, 'Illegal filename:', Fnam[F]);
      Halt;
      END;
   Fnam := Newname;
   END;


PROCEDURE Addext {(VAR Fnam: Filename; Ext: Fileext)};

   (* Adds extension Ext iff there is no extension. *)

   LABEL 99;
   VAR F,N,E: Integer;
       Newname: Filename;

   BEGIN
   Newname := Blankfilename;
   (* copy the part preceding the period *)
   F := 1;
   WHILE NOT (Fnam[F] IN ['.',' ']) DO
      BEGIN
      Newname[F] := Fnam[F];
      F := F + 1;
      END;
   (* put in the dot *)
   N := F;
   Newname[N] := '.';
   IF Fnam[F] = '.' THEN Goto 99; (* already has extension *)
   (* copy the extension *)
   FOR E := 1 TO Fileextlen DO
      IF Ext[E] <> ' ' THEN
	 BEGIN
	 N := N+1;
	 Newname[N] := Ext[E];
	 END;
   IF Fnam[F] <> ' ' THEN
      BEGIN
      Writeln (Output, 'Illegal filename:', Fnam[F]);
      Halt;
      END;
   Fnam := Newname;
99:END;




Procedure Parseoption (Str: Filename; VAR Switch: Identname; 
		       VAR Val: Integer);

   (* Given an option string, separates it into option name and value. *)

   VAR I: Integer;

   BEGIN
   Switch := Blankid;
   I := 2;
   While (Str[I] IN ['A'..'Z','a'..'z']) DO
      BEGIN
      IF (Ord (Str[I]) >= LcasA) AND (Ord (Str[I]) <= LcasZ) THEN
         Str[I] := Chr (Ord (Str[I]) - Casedif);
      Switch[I-1] := Str[I];
      I := I + 1;
      END;
   CASE Str[I] OF
      '+',' ': Val := 1;
      '-':     Val := 0;
      ':':     
	 BEGIN
	 I := I + 1;
	 IF (Str[I] < '0') AND (Str[I] > '9') THEN
	    BEGIN
	    Writeln (Output, 'Digit expected after ":" in command line.');
	    Halt;
	    END;
	 Val := 0;
	 WHILE (Str[I] >= '0') AND (Str[I] <= '9') DO
	    BEGIN
	    Val := Val*10 + Ord(Str[I])-Ord('0');
	    I := I + 1;
	    END;
	 END;
      END (* case *);
    END; (* parseoption *)




PROCEDURE GetCommandline {(VAR Commandline: Commandrec)};

  VAR Str: Filename;
      I: Integer;
  (* Gets switches and file names from command line. *)

   BEGIN
   WITH Commandline DO
      BEGIN
      Switchctr := 0;  Filectr := 0;
      FOR I := 1 to Argc-1 DO
         BEGIN
         Argv(I, Str);
         IF Str[1] = '-' THEN
	    BEGIN
	    Switchctr := Switchctr + 1;
	    Parseoption (Str, Switches[Switchctr], Switchvals[Switchctr]);
	    END
	 ELSE
	    BEGIN
	    Filectr := Filectr + 1;
	    Filenams[Filectr] := Str;
	    END;
         END;
     IF Filectr = 0 THEN
        BEGIN
        Writeln (Output, 'Source file name missing.');
        Halt;
	END;
     END;
  END;

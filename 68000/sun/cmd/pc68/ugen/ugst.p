(* -- UGST.PAS -- *)
(* Host compiler: *)
  (*%SetF HedrickPascal F *)
  (*%SetT UnixPascal T *)

(*%iff UnixPascal*)
{  (*$M-*)}
{}
{  PROGRAM UGST;}
{}
{   INCLUDE 'Ucode.Inc';}
{   INCLUDE 'Ug.Inc';}
{   INCLUDE 'Ugcd.Imp';}
(*%else*)
#include "ucode.h";
#include "ug.h";
#include "ugcd.h";
#include "ugst.h";
(*%endc*)

(*      This module manages the static areas and debugger tables.

        Every module has several statically-allocated areas of memory,
    corresponding to S-memory blocks in the U-code.  Following this
    convention, block number 1 is used for the global variables of the module,
    levels 2 and up for Fortran common arees, and level 0 for imported
    variables.  In addition, level -1 is use for constants.

	Each static area is represented by a label and a linked list of
    variables.  Each entry in the list contains either a certain part of the
    area which must be initialized to a given value, or a label that must be
    attached to a certain part of the area (e.g., if the variable is being
    exported, and therefore will be referenced by name.)

	All static areas are output at the end of the module, except for level
    0, shich has a special use (see Pail-8).  It is used to keep a
    correspondence between level 0 offset and the external name of the
    variable.  The procedure Find_Var retrieves the name of the variable. 

*)

CONST
   LabLastPrefixChar = 'L';	(* Last character of prefix of local labels *)

TYPE

   Varrecptr = ^Varrec;
   Varrec = 
      RECORD
      Vnxt: Varrecptr;
      Vdsp: Integer;  (* displacement within the static area *)
      Vlast: Integer;  (* last location to be initialized *)
      Vsize: Integer;  (* size of variable *)
      Vlbl: Labl;    (* label, if variable *)
      Vctyp: Consttype;
      Vcnst: Valu; (* initial value *)
      END;

      
   MFPtr = ^ModFileEntry;
   (* entry in Module Infoblock or File Infoblock table *)
   ModFileEntry = 
       PACKED RECORD
       Next: MFPtr;
       Tablename: Labl;
       END;

VAR

   (* Tables for debugger: *)
   Modhead, Modtail: MFptr;     (* module infoblock *)
   Filehead, Filetail: MFptr;   (* file infoblock *)
   Staticareas: ARRAY [-1..Maxcommons] OF   (* see comment on previous page *)
      RECORD 
         Lab: Labl;
         First, Last: Varrecptr
      END;
   Constsize: Integer;         (* Size of constant area *) 
   Olab: Labl;                  (* used for Ugen-generated labels *)
   EoOlab: Integer;             (* points to last char in Olab *)

(* exported procedures *)

(*%iff UnixPascal*)
{}
{PROCEDURE Createlabel (VAR Ilab: Labl);}
{   FORWARD;}
{}
{PROCEDURE InitSt;}
{   FORWARD;}
{}
{PROCEDURE Initmodule;}
{   FORWARD;}
{}
{PROCEDURE InitProc (VAR Dbginfo: Dbginforec);}
{   FORWARD;}
{}
{PROCEDURE SetStVar (Varbl:SharedVar; Val: Integer);}
{   FORWARD;}
{}
{PROCEDURE SetStaticAreaName (N: Integer; Lb: Labl);}
{   FORWARD;}
{}
{PROCEDURE GetAreaName (N: Integer; VAR Lb: Labl);}
{   FORWARD;}
{}
{PROCEDURE Addvar (Areanum, Displ, Last, Size: Integer; Vtype: Consttype;}
{                   VAR Constr: Valu; Lb: Labl);}
{   FORWARD;}
{}
{PROCEDURE Defineconst (VAR Cval: Valu; Len: Integer; Ctyp: Consttype; VAR Offst: Integer);}
{   FORWARD;}
{}
{PROCEDURE Findvar (Fakedispl: Integer; VAR Varname: Labl;}
{                    VAR Realdispl: Integer);}
{   FORWARD;}
{}
{PROCEDURE DumpArea (Areanum, Arealength: Integer);}
{   FORWARD;}
{}
{PROCEDURE DumpConstArea;}
{   FORWARD;}
{}
{PROCEDURE WritProcInfoblock (VAR Dbginfo: Dbginforec;}
{ 			       Highpage, Highline, Locctr: Integer);}
{   FORWARD;}
{}
{PROCEDURE WritModuleInfoblock (VAR Dbginfo: Dbginforec; Curpage,Curline: Integer);}
{   FORWARD;}
{}
{PROCEDURE WritFileInfoblock (VAR Dbginfo: Dbginforec; Stmtctr: Integer);}
{   FORWARD;}
{}
(*%endc*)


PROCEDURE Createlabel {(VAR Ilab: Labl)};

(* This routine creates a unique label to be used by Ugen.  The sequence
   goes: $$0 $$1 .. $$9 $$A $$B .. $$Z .. $$00 $$01 .. $$ZZ $$000 etc. *)

   VAR
      I: Integer;

   BEGIN

   IF Olab[EoOlab] = '9' THEN
      Olab[EoOlab] := 'A'
   ELSE
      Olab[EoOlab] := Succ(Olab[EoOlab]);
   I := EoOlab;
   WHILE (Olab[I] = Succ('Z')) DO
      (* perform the carry *)
	 BEGIN
	 Olab[I] := '0';
	 IF Olab[I-1] = '9' THEN 
	    Olab[I-1] := 'A'
	 ELSE Olab[I-1] := Succ(Olab[I-1]);
	 I := I-1;
         END;
   IF Olab[2] <> LabLastPrefixChar THEN
      BEGIN
      (* we have carried into column 2.  Shift everything right one place. *)
      IF EoOlab = Labchars THEN
         BEGIN
         UgenError ('Ran out of labels.            ', Novalue);
	 Olab := Initolab;
         EoOlab := 3;
         END
      ELSE
         BEGIN
         Olab[2] := LabLastPrefixChar;
         FOR I := 3 TO EoOlab+1 DO Olab[I] := '0';
         END;
      EoOlab := EoOlab + 1;
      END;
   Ilab := Olab;
   END;

(* InitSt Initproc Initmodule *)

PROCEDURE InitSt{};

   BEGIN
   (* Initialize debugger tables. *)
   New (Modhead);   Modhead^.Next := NIL;
   New (Filehead);  Filehead^.Next := NIL;
   Filetail := NIL;
   Olab := Initolab;
   EoOlab := 3;
   END;

PROCEDURE Initmodule{};
   VAR I: Integer;
   BEGIN
   FOR I := 0 TO Maxcommons DO 
      WITH Staticareas[I] DO
	 BEGIN
         First := NIL;
         Lab[1] := ' ';
	 END;
   Modtail := NIL;   (* initialize Module info block *)
   END;

PROCEDURE InitProc {(VAR Dbginfo: Dbginforec)};
   BEGIN
   (* Initialize constant area. *)
   Createlabel (Staticareas[-1].Lab);
   Constsize := 0;	(* init size of constant area *)
   Staticareas[-1].First := NIL;
   END;
 
PROCEDURE SetStVar {(Varbl:SharedVar; Val: Integer)};
   BEGIN
   END;

(* STATIC AREAS:  Addvar Defineconst Findvar Outputvar DumpArea  **)

PROCEDURE SetStaticAreaName {(N: Integer; Lb: Labl)};
   BEGIN
   Staticareas[N].Lab := Lb;
   END;

PROCEDURE GetAreaName {(N: Integer; VAR Lb: Labl)};
   BEGIN
   Lb := Staticareas[N].Lab;
   END;

PROCEDURE Addvar {(Areanum, Displ, Last, Size: Integer; Vtype: Consttype;
                   VAR Constr: Valu; Lb: Labl)};
   (* Adds a imported variable, a variable that must be initialized, or a
      constant string or set to the list of variables for a given static area.
      This list is ordered by location. *)
   VAR
      Tptr, Oldptr, Newrecptr: Varrecptr;

   BEGIN
   New (Newrecptr);
   WITH Newrecptr^ DO
      BEGIN
      Vnxt := NIL;
      Vdsp := Displ;
      Vlast := Last;
      Vsize := Size;
      Vctyp := Vtype;
      Vlbl := Lb;
      Vcnst := Constr;
      END;
   (* add to correct place in list *)
   WITH Staticareas[Areanum] DO
      BEGIN
      IF First = NIL THEN
         BEGIN (* no records in list yet *)
         First := Newrecptr;
         Last := Newrecptr;
         END
      ELSE IF Last^.Vdsp <= Displ THEN
         BEGIN (* add to end of list *)
         Last^.Vnxt := Newrecptr;
         Last := Newrecptr;
         END
      ELSE
         BEGIN (* insert in list *)
         Tptr := First;
         Oldptr := NIL;
         WHILE Tptr^.Vdsp <= Displ DO
            BEGIN
            Oldptr := Tptr;
            Tptr:= Tptr^.Vnxt;
            END;
         (* insert between oldptr and Tptr *)
         IF Oldptr = NIL THEN
            First := Newrecptr
         ELSE Oldptr^.Vnxt := Newrecptr;
         Newrecptr^.Vnxt := Tptr;
         END;
      END;
   END;

PROCEDURE Defineconst {(VAR Cval: Valu; Len: Integer; Ctyp: Consttype; VAR Offst: Integer)};
(* This routine takes the string or set constant in U and adds it
   to the static constant area for the current procedure. Set constants
   are aligned on word boundaries. *)

   BEGIN
   write('{Defineconst:Len:',Len:1);
   IF Ctyp = Ascizconst THEN Len := Len + 1;  (* Extra Null byte is added *)
   Addvar (-1, Constsize, Constsize, Len, Ctyp, Cval, Blabl);
   Offst := Constsize;
   Constsize := Constsize + Len;
   write('/Old.Off:',Offst:1,'/New:',Constsize:1,'}');
   IF Odd (Constsize) THEN Constsize := Constsize + 1;
(*   IF Constsize MOD APW <> 0 THEN
      Constsize := Constsize + APW - (Constsize MOD APW);*)
   END;

PROCEDURE Findvar {(Fakedispl: Integer; VAR Varname: Labl;
                    VAR Realdispl: Integer)};
   (* Given the fake displacement for an imported variable, finds the name
      of the variable, and its real displacement.  For instance, if an
      array had a fake displacement of 36, and an address of S 0 45 is
      encountered, the name of the array and the displacement from the
      base of the array (9), would be returned *)

   VAR
      Tptr, Lastptr: Varrecptr;
      Found: Boolean;
   BEGIN
   Tptr := Staticareas[0].First;
   Lastptr := NIL;
   Found := False;
   (* find the variable whose displacement is greater than FakeDispl *)
   WHILE (Tptr <> NIL) AND NOT Found DO
      IF Tptr^.Vdsp > Fakedispl THEN
         Found := True
      ELSE
         BEGIN
         Lastptr := Tptr;
         Tptr := Tptr^.Vnxt;
         END;
   IF (Lastptr = NIL) THEN
      Found := False  (* FakeDispl is before the lowest imported variable *)
   ELSE
     (* FakeDispl must less than the end of the highest variable imported *)
      Found := Fakedispl < Lastptr^.Vdsp + Lastptr^.Vsize;
   IF Found THEN
      BEGIN
      Varname := Lastptr^.Vlbl;
      Realdispl := Fakedispl - Lastptr^.Vdsp;
      END
   ELSE
      UgenError ('Var not imported              ',Fakedispl);
   END;


PROCEDURE DumpArea {(Areanum, Arealength: Integer)};
   (* Creates a static area, which may contain variables, some of which have
      labels, and some of which have initial values, and some both. *)

   VAR Tptr, Savedptr:  Varrecptr;
       Tcount: Integer;

   BEGIN
   WITH Staticareas[Areanum] DO
   IF Arealength > 0 THEN
      BEGIN
      Startarea (Lab, Areanum, Arealength, First <> NIL);
      Tptr := First;
      Tcount := 0;
      WHILE Tptr <> NIL DO
         BEGIN
         WITH Tptr^ DO
            BEGIN
            (* fill in space up to next variable *)
            IF Tcount < Vdsp THEN
	       BEGIN
               Putblock (Vdsp-Tcount);
	       Tcount := Vdsp;
	       END
            ELSE IF Tcount > Vdsp THEN
               UgenError ('Overlapping initializations.  ',Vdsp);
            IF Vlbl[1] <> ' ' THEN Putlab (Vlbl, 0, True, '                ');
            IF Vctyp <> Notconst THEN
	       BEGIN
	       IF Vctyp = Addrconst THEN
		  Putlab (Staticareas[1].Lab, Vcnst.Ival, False, Blankid)
	       ELSE
	          Putoutvar (Vcnst, Vctyp, (Vlast-Vdsp) DIV Vsize + 1);
	       Tcount := Vlast + Vsize;
	       IF Odd(Tcount) THEN Tcount := Tcount + 1;
	       END;
            END;
         Savedptr := Tptr;
         Tptr := Tptr^.Vnxt;
         Dispose (Savedptr);
         END;
      (* fill in any remaining space in the block *)
      IF (Tcount < Arealength) THEN
         Putblock (Arealength-Tcount);
      Endarea (Areanum, Arealength);
      END;
   END;

PROCEDURE DumpConstArea{};
   BEGIN
   DumpArea (-1, Constsize);
   END;

(* DEBUGGER TABLES:  Addloc Addlabelloc WritProcinfoblock WritModuleinfoblock WritFileinfoblock *)

(* These procedures are used to create Info Blocks for use by the debugger.
   See DBG2.TXT for the format of these tables.  There are three kinds of 
   tables: procedure tables, module tables, and one file table.  Each table 
   is collected in a linked list. *)


PROCEDURE GetModFileEntry (VAR Head, Tail: MFPtr);
    (* Gets a new Mod/File entry. Sets Tail to the new record.
       This procedure is used to add records to both the Module Infoblock and
       the File Infoblock, depending on what pointers are passed. *)
    BEGIN
    IF Tail = NIL THEN
       Tail := Head  (* begin new list *)
    ELSE 
       BEGIN
       New (Tail^.Next);
       Tail := Tail^.Next;
       Tail^.Next := NIL;
       END;
    END;

PROCEDURE WritProcInfoblock {(VAR Dbginfo: Dbginforec;
 			       Highpage, Highline, Locctr: Integer)};
  
   BEGIN
   (* create a unique label and save it for the Module Infoblock *)
   GetModFileEntry (Modhead, Modtail);
   WITH Dbginfo DO
      BEGIN
      Putlab (Curpiblab, 0, True, 'PIB             ');
      Modtail^.Tablename := Curpiblab;
      Putlab (Sourcelabl, 0, False, '^FIB            ');
      Putlab (Curmodlabl, 0, False, '^MIB            ');
      Putint (Cblk);
      Putlab (Curproclabl, 0, False, 'Addr of proc    ');
      Putlab (Curproclabl, Locctr, False, 'Addr of last st ');
      Putint (0); (* frame size *)
      Putint (0);; (* active regs *)
      Putpacked (Highpage, Highline); (* highest pageline *)
      Putid (Curprocname);
      Putint (-1); (* ptr to symbol table *)
      Putint (-1); (* ptr to PIB of enclosing procedure *)
      END;
   END;

PROCEDURE WritModuleInfoblock {(VAR Dbginfo: Dbginforec; Curpage,Curline: Integer)};
   VAR
      Tptr, Savedptr: MFPtr;
      Tlab: Labl;
      I: Integer;
   BEGIN
   Putlab (Dbginfo.Curmodlabl, 0, True, 'MIB             ');
   GetModFileEntry (Filehead, Filetail);
   Filetail^.Tablename := Dbginfo.Curmodlabl;
    
   Putlab (Staticareas[1].Lab, 0, False, 'Globals         ');
   IF Dbginfo.Highestcommon = 0 THEN
      Putint (-1)  (* common block pointer *)
   ELSE
      BEGIN
      Createlabel (Tlab);
      Putlab (Tlab, 0, False, 'Common block ptr');
      END;
   Putid (Dbginfo.CurModname);
   Putpacked (Curpage, Curline);
   IF Dbginfo.Modfirstproc[1] = ' ' THEN 
      Putint (0)
   ELSE Putlab (Dbginfo.Modfirstproc, 0, False, 'First proc      ');
   Putint (-1);  (* ptr to symbol table for globals *)
   Tptr := Modhead;
   Repeat
      Putlab (Tptr^.Tablename, 0, False, 'Proc            ');
      Savedptr := Tptr;
      Tptr := Tptr^.Next;
      Dispose (Savedptr);
   Until Tptr = NIL;
   Putint (-1);
   FOR I := 2 TO Dbginfo.Highestcommon DO
      BEGIN
      IF I = 2 THEN
         Putlab (Tlab, 0, True, 'Common table    ');
      Putlab (StaticAreas[I].Lab, 0, False, '                ');
      END;
   END;

PROCEDURE WritFileInfoblock {(VAR Dbginfo: Dbginforec; Stmtctr: Integer)};
   (* Writes out FIB. *)
   VAR
      Tptr, Savedptr: MFPtr;
   BEGIN
   (* If has main block, then this FIB is the main FIB. *)
   IF Dbginfo.Main[1] <> ' ' THEN
      Putlab (Mfiblab, 0, True, 'Main FIB        ');
   WITH Dbginfo DO
      BEGIN
      Putlab (Sourcelabl, 0, True, 'FIB             ');
      IF Profile THEN
         Putlab (Proflabl, 0, False, '^Profile table  ')
      ELSE Putint (0);
      Putfname (Sourcename);
      Putfname (Symbolname);
      IF Filefirstproc[1] = ' ' THEN 
	 Putint (0)
      ELSE Putlab (Filefirstproc, 0, False, 'First proc      ');
      END;
   Tptr := Filehead;
   Repeat
      Putlab (Tptr^.Tablename, 0, False, 'Module          ');
      Savedptr := Tptr;
      Tptr := Tptr^.Next;
      Dispose (Savedptr);
   Until Tptr = NIL;
   Putint (-1);
   IF Dbginfo.Profile THEN 
      BEGIN
      Putlab (Dbginfo.Proflabl, 0, True, 'Profile table   ');
      Putblock (Stmtctr);
      END;
   Putint (-1);
   END

(*%ift HedrickPascal *)
{   .}
(*%else*)
   ;
(*%endc*)

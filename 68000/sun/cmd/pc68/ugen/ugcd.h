FUNCTION Curtime: Integer;
   EXTERNAL;

PROCEDURE Resetsource (VAR Sname: Filename);
   EXTERNAL;

PROCEDURE UgenError (Msg: Errstring; Value: Integer);
   EXTERNAL;

PROCEDURE UgenMsg (Msg: Errstring; Value: Integer);
   EXTERNAL;

PROCEDURE SetCdVar (Varbl:SharedVar; Val: Integer);
   EXTERNAL;

PROCEDURE TraceUcode (U: Bcrec; Mnem: Opcstring);
   EXTERNAL;

PROCEDURE Writstats (Inittime, Readtime, Asmtime: Integer);
   EXTERNAL;

PROCEDURE WritComment (VAR U: Bcrec);
   EXTERNAL;

PROCEDURE Endfile (Main: Labl; Profile: Boolean);
   EXTERNAL;

PROCEDURE RuntimeRequest (Runset: Integer);
   EXTERNAL;

PROCEDURE Putlab (Lb: Labl; Disp: Integer; Defining: Boolean; Comment: Identname);
   EXTERNAL;

PROCEDURE Putint (I: Integer);
   EXTERNAL;

PROCEDURE Putblock (Size: Integer);
   EXTERNAL;

PROCEDURE Putpacked (Left, Right: Integer);
   EXTERNAL;

PROCEDURE Putid (Id: Identname);
   EXTERNAL;

PROCEDURE Putfname (Fn: Filename);
   EXTERNAL;

PROCEDURE Putoutvar (Cval: Valu; Ctyp: Consttype; Reps: Integer);
   EXTERNAL;

PROCEDURE StartArea (Arealab: Labl; Areanum, Arealength: Integer;
		      Initialized: Boolean);
   EXTERNAL;

PROCEDURE EndArea (Areanum, Arealength: Integer);
   EXTERNAL;

PROCEDURE WriteProc (VAR Dbginfo: Dbginforec; Msize, Maxtmp: Integer);
   EXTERNAL;

PROCEDURE Emit0 (Opc: Ocode);
   EXTERNAL;

PROCEDURE Emit1 (Opc: Ocode; At1: Addrtoken);
   EXTERNAL;

PROCEDURE Emit3 (Opc: Ocode; ResAt, At1, At2: AddrToken);
   EXTERNAL;

PROCEDURE Emit2 (Opc: Ocode; At1, At2: Addrtoken);
   EXTERNAL;

PROCEDURE Insert (Opc: Ocode; At1, At2: Addrtoken; After: Integer);
   EXTERNAL;

PROCEDURE EmitLab (Lbl: Labl);
   EXTERNAL;

PROCEDURE EmitLoc (Page, Line: Integer);
   EXTERNAL;

PROCEDURE Addlabelloc (Code: Integer; Ulbl: Labl);
   EXTERNAL;

PROCEDURE Initcd (Objname: Filename);
   EXTERNAL;

PROCEDURE NewCode (VAR Dbginfo: Dbginforec);
   EXTERNAL;


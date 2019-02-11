PROCEDURE Createlabel (VAR Ilab: Labl);
   EXTERNAL;

PROCEDURE InitSt;
   EXTERNAL;

PROCEDURE Initmodule;
   EXTERNAL;

PROCEDURE InitProc (VAR Dbginfo: Dbginforec);
   EXTERNAL;

PROCEDURE SetStVar (Varbl:SharedVar; Val: Integer);
   EXTERNAL;

PROCEDURE SetStaticAreaName (N: Integer; Lb: Labl);
   EXTERNAL;

PROCEDURE GetAreaName (N: Integer; VAR Lb: Labl);
   EXTERNAL;

PROCEDURE Addvar (Areanum, Displ, Last, Size: Integer; Vtype: Consttype;
                   VAR Constr: Valu; Lb: Labl);
   EXTERNAL;

PROCEDURE Defineconst (VAR Cval: Valu; Len: Integer; Ctyp: Consttype; VAR Offst: Integer);
   EXTERNAL;

PROCEDURE Findvar (Fakedispl: Integer; VAR Varname: Labl;
                    VAR Realdispl: Integer);
   EXTERNAL;

PROCEDURE DumpArea (Areanum, Arealength: Integer);
   EXTERNAL;

PROCEDURE DumpConstArea;
   EXTERNAL;

PROCEDURE WritProcInfoblock (VAR Dbginfo: Dbginforec;
 			       Highpage, Highline, Locctr: Integer);
   EXTERNAL;

PROCEDURE WritModuleInfoblock (VAR Dbginfo: Dbginforec; Curpage,Curline: Integer);
   EXTERNAL;

PROCEDURE WritFileInfoblock (VAR Dbginfo: Dbginforec; Stmtctr: Integer);
   EXTERNAL;


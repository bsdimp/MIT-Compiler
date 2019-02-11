PROCEDURE Inituwrite (Var Unam, Bnam: Filename);
   EXTERNAL;

FUNCTION Idlen (VAR Id: Identname): Integer;
   EXTERNAL;

PROCEDURE Uwrite (U: Bcrec);
   EXTERNAL;

FUNCTION Getdtyname (Dtyp: Datatype): Char;
   EXTERNAL;

FUNCTION Getmtyname (Mtyp: Memtype): Char;
   EXTERNAL;

PROCEDURE Writebuf (VAR Buf: Sourceline; Ctr: Integer);
   EXTERNAL;

Procedure Ucoid (Tag:Identname);
   EXTERNAL;

Procedure Ucofname (Fnam:Filename);
   EXTERNAL;

Procedure Writeoptn (Fname: Identname; Fint: Integer);
   EXTERNAL;

PROCEDURE EmitBcode;
   EXTERNAL;

PROCEDURE StopUcode;
   EXTERNAL;


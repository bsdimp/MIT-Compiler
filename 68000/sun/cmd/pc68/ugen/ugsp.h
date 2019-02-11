PROCEDURE Initsp;
   EXTERNAL;

PROCEDURE SetSpVar (Varbl:SharedVar; Val: Integer);
   EXTERNAL;

FUNCTION PowerofTwo (Num: Integer;  VAR Exp: Integer): Boolean;
   EXTERNAL;

FUNCTION AtpowerofTwo (VAR At: Addrtoken; VAR Shift: Integer): Boolean;
   EXTERNAL;

PROCEDURE Loadreg (VAR At: Addrtoken);
   EXTERNAL;

PROCEDURE GetAddr (VAR At: Addrtoken);
   EXTERNAL;

PROCEDURE Indirect (VAR At: Addrtoken; Newmdt: Mdatatype; Newlen: Integer);
   EXTERNAL;

PROCEDURE Adjaddr (VAR At: Addrtoken; Increment: Integer);
   EXTERNAL;

PROCEDURE Adjobject (VAR At: Addrtoken; Increment: Integer;
		      NewMdtype: Mdatatype; Newlen: Integer);
   EXTERNAL;

PROCEDURE CollapseIndex (VAR At1, At2: Addrtoken);
   EXTERNAL;

PROCEDURE SignedUnpack (VAR At: Addrtoken);
   EXTERNAL;

PROCEDURE MakFramePointerAt (VAR At: AddrToken; TgtLevel,Curlevel: Integer);
   EXTERNAL;

PROCEDURE MakblkoffsetAt (VAR At: Addrtoken; VAR U: Bcrec;
                            Tgtlevel,CurLevel: Integer; Cntx: Contexts);
   EXTERNAL;

PROCEDURE Moveblock (VAR Dest, Source: AddrToken;
			Len: Integer; Isaddress: Boolean);
   EXTERNAL;

PROCEDURE Movevblock (Dest, Source, Size: AddrToken);
   EXTERNAL;

PROCEDURE Zeroblock  (Dest: AddrToken; Len: Integer);
   EXTERNAL;

PROCEDURE Oneblock  (Dest, Len: AddrToken);
   EXTERNAL;

PROCEDURE Moveit (VAR Dest, Source: AddrToken);
   EXTERNAL;

PROCEDURE Moveregs (Insert,Save: Boolean; Rgs: Regset; VAR Locat: AddrToken);
   EXTERNAL;

PROCEDURE Transferregs (Save: Boolean; Pregs: Regset);
   EXTERNAL;

PROCEDURE EmitEntrycode (Proclabl: Labl; Savedisplay: Boolean;
			VAR Dbginfo: Dbginforec; Curlvl: Integer);
   EXTERNAL;

PROCEDURE EmitExitcode (Restoredisplay: Boolean; Curlvl: Integer;
			VAR Dbginfo: Dbginforec);
   EXTERNAL;

PROCEDURE CallDebugger;
   EXTERNAL;

PROCEDURE RestoreRegs (Rgs: Regset);
   EXTERNAL;

PROCEDURE SaveRegs (Rgs: Regset);
   EXTERNAL;

PROCEDURE Cutstack (Tgtlevel, Curlevel: Integer);
   EXTERNAL;

PROCEDURE RestFrame;
   EXTERNAL;

PROCEDURE Savepassedprocdisplay (VAR At: Addrtoken; Curlev, Passeelev: Integer);
   EXTERNAL;

PROCEDURE Restrcalleedisplay (VAR At: Addrtoken);
   EXTERNAL;

PROCEDURE Restorcallerdisplay (VAR At: Addrtoken);
   EXTERNAL;

PROCEDURE Pushparm (ParAt: Addrtoken; Parcount: Integer);
   EXTERNAL;

PROCEDURE MakFuncResAt (VAR FuncresAt: AddrToken);
   EXTERNAL;

PROCEDURE Callproc (Parcount: Integer; Uplevel: Boolean; Globaloffset: Integer;
                    Proc: Addrtoken);
   EXTERNAL;

PROCEDURE Retrnfromcall (Globaloffset: Integer; VAR Funcres: Addrtoken);
   EXTERNAL;

PROCEDURE Emitbinaryop (Op: Icode; VAR TgtAt, At1, At2: Addrtoken);
   EXTERNAL;

PROCEDURE Emitunaryop (Op: Icode; VAR TgtAt, At1: Addrtoken);
   EXTERNAL;

PROCEDURE EmitbnvectorOp (Op: Icode; VAR TgtAt, At1, At2: Addrtoken);
   EXTERNAL;

PROCEDURE Jumpifoutofrange (VAR At: Addrtoken; Lowbound, Highbound: Integer;
				Dest: Labl);
   EXTERNAL;

PROCEDURE SimpleJump (Dest: Labl);
   EXTERNAL;

PROCEDURE CaseJump (Dest: Labl);
   EXTERNAL;

PROCEDURE Jumpindirect (Dest: Addrtoken);
   EXTERNAL;

PROCEDURE Compare (Op: Icode; VAR TgtAt, At1, At2: Addrtoken; Dest: Labl);

   EXTERNAL;

PROCEDURE BlockCompare (Op: Icode; VAR TgtAt, At1, At2: Addrtoken; Dest: Labl);
   EXTERNAL;

PROCEDURE Stringcompare (Op: Icode; VAR TgtAt, At1, At2, SizeAt: AddrToken;
			       Dest: Labl);
   EXTERNAL;

PROCEDURE Emitboundscheck (VAR At1: Addrtoken; Lowbound, Highbound: Integer);
   EXTERNAL;

PROCEDURE Checkblock (VAR At1: Addrtoken; Len: Integer);
   EXTERNAL;

PROCEDURE Unpack (VAR At: Addrtoken);
   EXTERNAL;

PROCEDURE Extractbyte (VAR At:Addrtoken; Bitoffset, Len: Integer;
			SignExtend, Indirct: Boolean);
   EXTERNAL;

PROCEDURE Depositbyte (VAR TgtAt, At:Addrtoken; Bitoffset, Len: Integer;
			Indirct: Boolean);
   EXTERNAL;

PROCEDURE ByteIndex (VAR BaseAt, IndexAt: Addrtoken; Elsize: Integer);
   EXTERNAL;

PROCEDURE Index (VAR BaseAt, IndexAt: Addrtoken; Elsize: Integer);
   EXTERNAL;

PROCEDURE Indextable (VAR Tablepart, IndexAt: Addrtoken; Table: Labl);
   EXTERNAL;

PROCEDURE Indexset (VAR IndexAt, SetAt, Tablepart, Setpart, DivAt: Addrtoken;
		    Table: Labl);
   EXTERNAL;


PROCEDURE Initrg;
   EXTERNAL;

PROCEDURE CopyAt (VAR Dest, Source: Addrtoken);
   EXTERNAL;

PROCEDURE Inittemps;
   EXTERNAL;

PROCEDURE SetRgVar (Varbl:SharedVar; Val: Integer);
   EXTERNAL;

FUNCTION GetMaxtmp: Integer;
   EXTERNAL;

PROCEDURE Getstats (VAR Bcount, Lcount: Integer);
   EXTERNAL;

PROCEDURE Returnreg (Rg: Register);
   EXTERNAL;

PROCEDURE Clean (At: Addrtoken);
   EXTERNAL;

PROCEDURE Push (At: Addrtoken);
   EXTERNAL;

PROCEDURE Pop (VAR At : Addrtoken);
   EXTERNAL;

PROCEDURE Emptystack;
   EXTERNAL;

FUNCTION IsWorkReg (VAR At: Addrtoken): Boolean;
   EXTERNAL;

FUNCTION WorkReg (Rg: Register): Boolean;
   EXTERNAL;

FUNCTION IsFree (Rg: Register): Boolean;
   EXTERNAL;

FUNCTION PairFree (Rg: Register): Boolean;
   EXTERNAL;

FUNCTION SoleUser (Rg: Register): Boolean;
   EXTERNAL;

PROCEDURE ReserveRegs (Regclass, Offset, Size: Integer; VAR Dbginfo: Dbginforec);
   EXTERNAL;

FUNCTION Regno (Offset: Integer): Register;
   EXTERNAL;

PROCEDURE Freeworkreg (Rg: Register);
   EXTERNAL;

PROCEDURE SplitAt (VAR Oldat, At1, At2: Addrtoken);
   EXTERNAL;

FUNCTION Alocateregpair (Mdtyp: Mdatatype): Register;
   EXTERNAL;

FUNCTION Allocatereg (Mdtyp: Mdatatype): Register;
   EXTERNAL;

PROCEDURE GetThatReg (Rg: Register; Mdtyp: Mdatatype);
   EXTERNAL;

PROCEDURE Grabreg (Rg:Register);
   EXTERNAL;

PROCEDURE Grabpair (Rg:Register);
   EXTERNAL;

PROCEDURE Killreg (Rg:Register);
   EXTERNAL;

PROCEDURE Bindreg (Rg: Register; Mty: Memtype; Blk, Offst: Integer);
   EXTERNAL;

FUNCTION Matchreg (Mdtype: Mdatatype; Mty: Memtype; Blk, Offst: Integer; VAR Vreg: Register;
		    MultiplerefOk: Boolean): Boolean;
   EXTERNAL;

PROCEDURE Killloc(Mty: Memtype; Blk, Offst: Integer);
   EXTERNAL;

PROCEDURE Killbindings;
   EXTERNAL;

PROCEDURE Basicblock (Alldead: Boolean);
   EXTERNAL;

PROCEDURE Loadstack;
   EXTERNAL;

PROCEDURE Callerregs (VAR Rgs: Regset);
   EXTERNAL;

PROCEDURE Calleeregs (VAR Rgs: Regset);
   EXTERNAL;

PROCEDURE Savestack;
   EXTERNAL;

FUNCTION Recycletemp (Size: Integer): Tempptr;
   EXTERNAL;

PROCEDURE Gettemp (VAR Tptr: Tempptr; Size: Integer; VAR Tlb: Integer);
   EXTERNAL;

FUNCTION Expandtemp (VAR At: Addrtoken; NewSize: Integer): Boolean;
   EXTERNAL;


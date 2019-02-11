FUNCTION IsTemp (VAR At: Addrtoken): Boolean;
   EXTERNAL;

FUNCTION IsBitpacked (VAR U: Bcrec): Boolean;
   EXTERNAL;

FUNCTION IsOne (VAR At: Addrtoken): Boolean;
   EXTERNAL;

FUNCTION IsZero (VAR At: Addrtoken): Boolean;
   EXTERNAL;

FUNCTION IsBetween (VAR At: Addrtoken; lo, hi: Integer): Boolean;
   EXTERNAL;

FUNCTION EquAt (VAR At1, At2: Addrtoken): Boolean;
   EXTERNAL;

PROCEDURE CoerceMtypes (VAR At1, At2: Addrtoken);
   EXTERNAL;

FUNCTION MachineType (Dtype: Datatype;  Len: Integer): Mdatatype;
   EXTERNAL;

FUNCTION DtyptoLen (Dtyp: Datatype): Integer;
   EXTERNAL;

FUNCTION LenToMdtype (Len: Integer): Mdatatype;
   EXTERNAL;

FUNCTION DtypetoCtype (Dtyp: Datatype; VAR Val: Valu): Consttype;
   EXTERNAL;

PROCEDURE MakConstAt (VAR At: Addrtoken; VAR U: Bcrec);
   EXTERNAL;

PROCEDURE MakregAt (VAR At: Addrtoken; Mdtyp: Mdatatype; Regr: Register);
   EXTERNAL;

PROCEDURE MakTmpRegAt (VAR At: Addrtoken; Mdtyp: Mdatatype);
   EXTERNAL;

PROCEDURE MakAddrAt (VAR At: Addrtoken; Mdtyp: Mdatatype;
 		           Dspl: Integer; Lbl: Labl; Cntx: Contexts);
   EXTERNAL;

PROCEDURE MakrgoffAt (VAR At: Addrtoken; Mdtyp: Mdatatype;
			  Rg, Dspl: Integer; Fix: Fixups;
		          Cntx: Contexts);
   EXTERNAL;

PROCEDURE MakintconstAt (VAR At: Addrtoken; I:Integer);
   EXTERNAL;

PROCEDURE MaktempAt (VAR At: Addrtoken; Mdtyp: Mdatatype; Len: Integer;
                       Cntx: Contexts);
   EXTERNAL;

PROCEDURE MakpackedconstAt (VAR At: Addrtoken; I,J: Integer);
   EXTERNAL;

PROCEDURE MakboundspairAt (VAR At: Addrtoken; I,J:Integer);
   EXTERNAL;

PROCEDURE Initat;
   EXTERNAL;


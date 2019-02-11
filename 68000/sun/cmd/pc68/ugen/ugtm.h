FUNCTION Collindirect (VAR At: Addrtoken): Boolean;
   EXTERNAL;

FUNCTION Colladjust (VAR At: Addrtoken; Adjlength : Integer): Boolean;
   EXTERNAL;

FUNCTION Coladaddr (VAR At1,At2: Addrtoken) : Boolean;
   EXTERNAL;

FUNCTION ColShift (VAR At: AddrToken; Shft: Integer): Boolean;
   EXTERNAL;

FUNCTION ColAdInt (VAR At1, At2: AddrToken): Boolean;
   EXTERNAL;

PROCEDURE InitTm;
   EXTERNAL;


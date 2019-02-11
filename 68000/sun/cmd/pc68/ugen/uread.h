PROCEDURE SwitchtoBcode (Bname: Filename);
   EXTERNAL;

PROCEDURE ReadUinstr (VAR U: Bcrec);
   EXTERNAL;

PROCEDURE GetOpcstr (Op: Uopcode; VAR Mnem: Opcstring);
   EXTERNAL;

PROCEDURE Initur (Uname: Filename);
   EXTERNAL;


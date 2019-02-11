PROGRAM floattest(output,input);
CONST
   MaxDecDigits = 18;
   MaxBinDigits = 56;
   MaxPosExp = 127;
   MaxNegExp = -127;
   LeastBit = -184;	(* MaxNegBit - MaxBinDigits - 1*)
TYPE
   (* For both Decimal- and BinaryFloat, the decimal/binary point
    * is between Mantissa[1] and Mantissa[2]. *)
   DecimalFloat = RECORD
      Exponent: Integer;
      Mantissa: PACKED ARRAY [1..MaxDecDigits] OF 0..9;
      END;
   BinaryFloat = RECORD
      Exponent: Integer;
      Mantissa: PACKED ARRAY [1..MaxBinDigits] OF 0..1;
      END;
   SignCode = -1..1;
   string = packed array [1..256] of char;
VAR
   I:Integer; Negative: Boolean;
   TwoToThe: ARRAY [LeastBit..MaxPosExp] OF DecimalFloat;
   Buf: DecimalFloat; binbuf:binaryfloat; SBuf:String;

PROCEDURE GetDec (VAR Buf: String; VAR I:Integer; VAR D:DecimalFloat);
   VAR NegExp: Boolean; J: Integer;
   BEGIN
   WHILE Buf[I] = ' ' DO I := I + 1;
   Negative := Buf[I] = '-';
   IF Negative OR (Buf[I] = '+') THEN I := I + 1;
   WHILE Buf[I] = '0' DO I := I + 1;
   J := 1;
   WHILE (Buf[I] >= '0') AND (Buf[I] <= '9') AND (J <= MaxDecDigits) DO
      BEGIN D.Mantissa[J] := Ord(Buf[I]) - Ord('0'); I := I+1; J := J+1; END;
   D.Exponent := J - 2;
   IF Buf[I] = '.' THEN
      BEGIN
      I := I + 1;
      WHILE (Buf[I] >= '0') AND (Buf[I] <= '9') AND (J <= MaxDecDigits) DO
         BEGIN
	 D.Mantissa[J] := Ord(Buf[I]) - Ord('0');
	 I := I+1; J := J+1;
	 END;
      END;
   IF (Buf[I] = 'E') OR (Buf[I] = 'e') THEN
      BEGIN
      I := I + 1;
      NegExp := Buf[I] = '-';
      IF NegExp OR (Buf[I] = '+') THEN I := I + 1;
      J := 0;
      WHILE (Buf[I] >= '0') AND (Buf[I] <= '9') DO
         BEGIN J := 10*J + Ord(Buf[I]) - Ord('0'); I := I + 1; END;
      IF NegExp THEN J := - J;
      D.Exponent := D.Exponent + J;
      END;
   END;
      
  
PROCEDURE PutDec(VAR D:DecimalFloat);
  VAR I:Integer;
  BEGIN
  write(' ',D.Exponent:1,'E * ',D.Mantissa[1]:1,'.');
  FOR I:=2 TO MaxDecDigits DO
     IF (D.Mantissa[I] >= 0) AND (D.Mantissa[I] <= 9) THEN
        write( Chr (D.Mantissa[I] + Ord('0')))
     ELSE write ('{',D.Mantissa[I]:1,'}');
  END;

PROCEDURE WriteReal (VAR R: BinaryFloat; Double: Boolean);
   VAR HexDigits: ARRAY [1..16] OF Char; I:Integer;

   PROCEDURE PutHex (I:Integer);
      BEGIN
      Write (HexDigits[(I MOD 16) + 1]);
      END;

   FUNCTION BitsToInt(First,Len:Integer):Integer;
      VAR I, Sum: Integer;
      BEGIN
      Sum := 0;
      FOR I := First TO First + Len - 1 DO Sum := Sum+Sum + R.Mantissa[I];
      BitsToInt := Sum;
      END;

   BEGIN
   HexDigits := '0123456789ABCDEF';
   IF R.Exponent < MaxNegExp THEN
      BEGIN Write ('#0'); IF Double THEN Write (',#0'); END
   ELSE
      BEGIN
      I := R.Exponent + 128;
      IF Negative THEN I := I + 256;
      Write('#/');
      Puthex (I DIV 32); PutHex (I DIV 2);
      R.Mantissa[1] := I MOD 2;
      I := 1;
      WHILE I < 25 DO BEGIN PutHex(BitsToInt(I, 4)); I := I + 4; END;
      IF Double THEN
         BEGIN
         Write (',#/');
	 WHILE I < 57 DO BEGIN PutHex(BitsToInt(I, 4)); I := I + 4; END;
         END;
      END;
   END;
      
PROCEDURE DoubleDec (VAR Outp, Inp: DecimalFloat);
   VAR I, Carry, Digit: Integer;
   BEGIN
   Carry := 0;
   FOR I := MaxDecDigits DOWNTO 1 DO
      BEGIN
      Digit := Inp.Mantissa[I] + Inp.Mantissa[I] + Carry;
      Carry := Ord (Digit >= 10);
      IF Carry > 0 THEN Digit := Digit - 10;
      Outp.Mantissa[I] := Digit;
      END;
   IF Carry = 0 THEN Outp.Exponent := Inp.Exponent
   ELSE
      BEGIN
      Outp.Exponent := Inp.Exponent + 1;
      FOR I := MaxDecDigits DOWNTO 2 DO
         Outp.Mantissa[I] := Outp.Mantissa[I - 1];
      Outp.Mantissa[1] := Carry;
      END;
   END;

PROCEDURE HalveDec (VAR Outp, Inp: DecimalFloat);
   VAR IIn, IOut, Prev: Integer;
   BEGIN
   IIn := 1; Iout := 1; Outp.Exponent := Inp.Exponent; Prev := 0;
   IF Inp.Mantissa[1] = 1 THEN
      BEGIN IIn := 2; Outp.Exponent := Inp.Exponent - 1; Prev := 5 END;
   WHILE IIn <= MaxDecDigits DO
      BEGIN
      Outp.Mantissa[IOut] := Inp.Mantissa[IIn] DIV 2 + Prev;
      IF Odd(Inp.Mantissa[IIn]) THEN Prev := 5 ELSE Prev := 0;
      IIn := IIn + 1; IOut := IOut + 1;
      END;
   IF IOut <= MaxDecDigits THEN Outp.Mantissa[IOut] := Prev;
   END;

PROCEDURE InitDec;
   VAR I: Integer;
   BEGIN
   WITH TwoToThe[0] DO
      BEGIN
      Exponent := 0; Mantissa[1] := 1;
      FOR I := 2 TO MaxDecDigits DO Mantissa[I] := 0;
      END;
   FOR I := 1 TO MaxPosExp DO DoubleDec (TwoToThe[I], TwoToThe[I-1]);
   FOR I := -1 DOWNTO LeastBit DO
      HalveDec (TwoToThe[I], TwoToThe[I+1]);
   END;

FUNCTION SubtractDec (VAR Dec1, Dec2: DecimalFloat):SignCode;
   (* IF Dec1 >= Dec2 THEN Dec1 := Dec1 - Dec2; Result := Signum(Dec1-Dec2) *)
   VAR
      Work: PACKED ARRAY [1..MaxDecDigits] OF 0..9;
      I, Diff, Delta, Borrow: Integer;
   BEGIN
   Delta := Dec1.Exponent - Dec2.Exponent;
   IF Delta < 0 THEN SubtractDec := -1
   ELSE
      BEGIN
      Borrow := 0;
      FOR I := MaxDecDigits DOWNTO 1 DO
         BEGIN
	 IF I > Delta THEN Borrow := Borrow + Dec2.Mantissa[I - Delta];
	 Diff := Dec1.Mantissa[I] - Borrow;
	 Borrow := Ord(Diff < 0);
	 Work[I] := Diff + 10*Borrow;
	 END;
      IF Borrow > 0 THEN SubtractDec := -1
      ELSE
         BEGIN
         I := 1;
         WHILE (Work[I] = 0) AND (I < MaxDecDigits) DO I := I + 1;
         Delta := I - 1;
	 IF Work[I] = 0 THEN
	    BEGIN SubtractDec:= 0; Dec1.Exponent := 0 END
	 ELSE
	    BEGIN SubtractDec:= 1; Dec1.Exponent := Dec1.Exponent - Delta END;
         FOR I := 1 TO MaxDecDigits - Delta DO
            Dec1.Mantissa[I] := Work[I + Delta];
	 FOR I := MaxDecDigits - Delta + 1 TO MaxDecDigits DO
	    Dec1.Mantissa[I] := 0;
	 END;
      END;
   END;

PROCEDURE Float10to2 (VAR Decimal: DecimalFloat; VAR Binary: BinaryFloat);
   VAR D: DecimalFloat; I, BitPos, Sign: Integer;
   BEGIN
   Sign := 1;
   D := Decimal;
   BitPos := 0;
   I := MaxPosExp;
   Binary.Exponent := MaxNegExp - 1;
   WHILE (Sign <> 0) AND (BitPos < MaxBinDigits) AND (I >= LeastBit) DO
      BEGIN
      Sign := SubtractDec (D, TwoToThe[I]);
      IF (BitPos > 0) OR (Sign >= 0) THEN
         BEGIN
write('I:',I:1,' BP:',BitPos:1,' S:', Sign:2);  putdec(D);writeln;
         IF BitPos = 0 THEN Binary.Exponent := I;
	 BitPos := BitPos + 1;
         Binary.Mantissa[BitPos] := Ord (Sign >= 0);
	 END;
      I := I - 1;
      END;
   WHILE BitPos < MaxBinDigits DO
      BEGIN BitPos := BitPos + 1; Binary.Mantissa[BitPos] := 0; END;
   END;

PROCEDURE GetLine (VAR l:String);
   VAR I: Integer;
   BEGIN
   I := 1;
   while not eoln do begin read(l[i]); i:= i+1; end;
   readln;
   l[i] := ' ';
   END;
BEGIN
InitDec;
readln;
GetLine (SBuf);
WHILE SBuf[1] <> '*' DO
   BEGIN
   I := 1; GetDec(SBuf, I, buf); PutDec (buf); write (' = ');
   float10to2(buf,binbuf);
   write(' ',binbuf.exponent:1,'B * ',binbuf.mantissa[1],'.');
   for i:= 2 to MaxBinDigits do
     if binbuf.mantissa[i] IN [0..1] THEn write(binbuf.mantissa[i]:1)
     else write('{',binbuf.mantissa[i]:1,'}');
   writereal(binbuf,true);writeln;
   GetLine (SBuf);
   END;
END.

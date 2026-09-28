with Ada.Long_Float_Text_IO;
with Ada.Numerics.Long_Elementary_Functions;
with Ada.Strings.Fixed;

package body Raven.Numbers is

   package Wide_Conversions is
     new Signed_Conversions (Long_Long_Integer);

   package Double_Conversions is
     new Float_Conversions (Long_Float);

   Byte_Base : constant Big_Integer := To_Big_Integer (256);

   --  The Number an exact integer is, made normal: a fixnum when it
   --  fits, and a bignum when it does not.

   function Normal (Wide : Long_Long_Integer) return Number;
   function Normal (Big : Big_Integer) return Number;

   --  And an exact rational, made an integer when its denominator is
   --  one, which is how (/ 6 2) is the fixnum 3.

   function Normal (Real : Big_Real) return Number;

   --  Any exact number as a Big_Real, for an operation one of whose
   --  operands is a rational.

   function To_Real (N : Number) return Big_Real
     with Pre => N.Kind /= Flonum;

   function Either_Ratnum (Left, Right : Number) return Boolean
   is (Left.Kind = Ratnum or else Right.Kind = Ratnum);

   --  An inexact answer, refused if it is past what a double holds.
   --  Ada gives an infinity or raises there depending on the checks it
   --  was built with, and R7RS's +inf.0 is not something raven has.

   function Checked_Inexact (Value : Long_Float) return Number;

   --  Left Op Right as doubles.  The operands are made doubles before
   --  anything is done with them, so a bignum too large for one says so
   --  itself; what goes wrong after that is the answer overflowing.

   function Double_Op
     (Left  : Number;
      Op    : Character;
      Right : Number)
      return Number;

   --  An exact number as a Big_Integer, and any number as a double, for
   --  an operation whose operands are not both fixnums.

   function To_Big (N : Number) return Big_Integer
     with Pre => N.Kind in Fixnum | Bignum;

   function To_Double (N : Number) return Long_Float;

   function Both_Fixnums (Left, Right : Number) return Boolean
   is (Left.Kind = Fixnum and then Right.Kind = Fixnum);

   function Either_Inexact (Left, Right : Number) return Boolean
   is (Left.Kind = Flonum or else Right.Kind = Flonum);

   function Widened (N : Number) return Long_Long_Integer
   is (Long_Long_Integer (N.Value))
     with Pre => N.Kind = Fixnum;

   --  The shortest decimal that reads back as Value, written as R7RS
   --  writes a number: a point always, and an exponent only when the
   --  number is far from one.

   function Double_Image (Value : Long_Float) return String;

   --  The largest integer whose square is no more than N, by Newton's
   --  method from above.

   function Integer_Root (N : Big_Integer) return Big_Integer
     with Pre => N >= To_Big_Integer (0);

   --  Nought as a Number, for the comparisons that ask about a sign.

   Zero : constant Number := (Kind => Fixnum, Value => 0);

   ---------
   -- Add --
   ---------

   function Add (Left, Right : Number) return Number
   is (if Either_Inexact (Left, Right)
       then Double_Op (Left, '+', Right)
       elsif Either_Ratnum (Left, Right)
       then Normal (To_Real (Left) + To_Real (Right))
       elsif Both_Fixnums (Left, Right)
       then Normal (Widened (Left) + Widened (Right))
       else Normal (To_Big (Left) + To_Big (Right)));

   -----------
   -- Apply --
   -----------

   function Apply (How : Elementary; N : Number) return Number is
      package F renames Ada.Numerics.Long_Elementary_Functions;

      X    : constant Long_Float := To_Double (N);
      Name : constant String :=
               (case How is
                   when Exp  => "exp",  when Log  => "log",
                   when Sin  => "sin",  when Cos  => "cos",
                   when Tan  => "tan",  when Asin => "asin",
                   when Acos => "acos", when Atan => "atan");
   begin
      if How = Log and then X <= 0.0 then
         raise Constraint_Error with
           "log: " & Image (N) & " has no real logarithm, and raven has"
           & (if X = 0.0 then " no infinities" else " no complex numbers");
      elsif How in Asin | Acos and then abs X > 1.0 then
         raise Constraint_Error with
           Name & ": " & Image (N) & " is outside -1 .. 1, and raven has"
           & " no complex numbers";
      end if;

      --  What goes wrong from here on is the answer, not the argument:
      --  exp of a thousand is past what a double holds.

      begin
         return Checked_Inexact
           (case How is
               when Exp  => F.Exp (X),
               when Log  => F.Log (X),
               when Sin  => F.Sin (X),
               when Cos  => F.Cos (X),
               when Tan  => F.Tan (X),
               when Asin => F.Arcsin (X),
               when Acos => F.Arccos (X),
               when Atan => F.Arctan (X));
      exception
         when Constraint_Error | Ada.Numerics.Argument_Error =>
            raise Constraint_Error with
              Name & ": " & Image (N) & " has no answer a double holds";
      end;
   end Apply;

   ----------------
   -- Arctangent --
   ----------------

   function Arctangent (Y, X : Number) return Number is
      Yd : constant Long_Float := To_Double (Y);
      Xd : constant Long_Float := To_Double (X);
   begin
      if Yd = 0.0 and then Xd = 0.0 then
         raise Constraint_Error with "atan: the point (0, 0) has no angle";
      end if;

      return Checked_Inexact
        (Ada.Numerics.Long_Elementary_Functions.Arctan (Yd, Xd));
   end Arctangent;

   ---------------------
   -- Checked_Inexact --
   ---------------------

   function Checked_Inexact (Value : Long_Float) return Number is
   begin
      if not Value'Valid or else abs Value > Long_Float'Last then
         raise Constraint_Error with
           "inexact overflow: past what a double holds";
      end if;

      return (Kind => Flonum, Inexact => Value);
   end Checked_Inexact;

   ------------
   -- Decode --
   ------------

   function Decode
     (VM : Raven_VM'Class;
      X  : Object)
      return Number
   is
   begin
      if Raven.Objects.Is_Integer (X) then
         return (Kind => Fixnum, Value => Raven.Objects.To_Integer (X));
      elsif Raven.Objects.Is_Float (X) then
         return (Kind    => Flonum,
                 Inexact => Long_Float (Raven.Objects.To_Float (X)));
      elsif Raven.Objects.Is_Flonum (X) then
         return (Kind => Flonum, Inexact => VM.Flonum_Value (X));
      elsif Raven.Objects.Is_Ratnum (X) then
         return (Kind  => Ratnum,
                 Ratio =>
                   To_Big (Decode (VM, VM.Ratnum_Numerator (X)))
                   / To_Big (Decode (VM, VM.Ratnum_Denominator (X))));
      end if;

      --  Most significant byte first, so each is one multiply and one
      --  add on what is there already.

      declare
         Result : Big_Integer := To_Big_Integer (0);
      begin
         for Index in reverse 0 .. VM.Vector_Length (X) - 1 loop
            Result :=
              Result * Byte_Base
              + To_Big_Integer
                  (Raven.Objects.To_Integer (VM.Vector_Element (X, Index)));
         end loop;

         return (Kind => Bignum,
                 Big  => (if VM.Is_Negative (X) then -Result else Result));
      end;
   end Decode;

   -----------------
   -- Denominator --
   -----------------

   function Denominator (N : Number) return Number
   is (case N.Kind is
          when Fixnum | Bignum => (Kind => Fixnum, Value => 1),
          when Ratnum          => Normal (Denominator (N.Ratio)),
          when Flonum          => To_Inexact (Denominator (To_Exact (N))));

   ------------
   -- Divide --
   ------------

   function Divide (Left, Right : Number) return Number is
   begin
      if Equal (Right, (Kind => Fixnum, Value => 0)) then
         raise Constraint_Error with "divide by zero";
      end if;

      --  Exact, and an integer when it comes out even: two fixnums that
      --  divide exactly are divided as fixnums, and anything else is a
      --  rational made normal.  The one fixnum division that does not
      --  fit, the smallest by -1, is one past the largest and is a
      --  bignum like any other.

      if Either_Inexact (Left, Right) then
         return Double_Op (Left, '/', Right);
      elsif Both_Fixnums (Left, Right)
        and then Left.Value rem Right.Value = 0
      then
         return Normal (Widened (Left) / Widened (Right));
      else
         return Normal (To_Real (Left) / To_Real (Right));
      end if;
   end Divide;

   ------------------
   -- Double_Image --
   ------------------

   function Double_Image (Value : Long_Float) return String is
      use Ada.Strings.Fixed;

      Buffer : String (1 .. 40);
      Last   : Natural;
   begin
      if Value = 0.0 then
         return (if Long_Float'Copy_Sign (1.0, Value) < 0.0
                 then "-0.0" else "0.0");
      end if;

      --  The fewest significant digits that read back as the same
      --  double.  Seventeen always do.

      for Significant in 1 .. 17 loop
         Ada.Long_Float_Text_IO.Put
           (Buffer, Value, Aft => Significant - 1, Exp => 4);
         exit when Long_Float'Value (Buffer) = Value;
      end loop;

      --  Buffer is now d.ddddE+eeee, with a sign.  Taken apart into the
      --  sign, the digits without the point, and where the point is.

      declare
         Text     : constant String := Trim (Buffer, Ada.Strings.Both);
         E        : constant Natural := Index (Text, "E");
         Negative : constant Boolean := Text (Text'First) = '-';
         Mantissa : constant String :=
                      Text ((if Negative then Text'First + 1 else Text'First)
                            .. E - 1);
         Power    : constant Integer :=
                      Integer'Value (Text (E + 1 .. Text'Last));
         Figures  : String (1 .. Mantissa'Length);
         Count    : Natural := 0;
         Sign     : constant String := (if Negative then "-" else "");
      begin
         for Ch of Mantissa loop
            if Ch /= '.' then
               Count := Count + 1;
               Figures (Count) := Ch;
            end if;
         end loop;

         Last := Count;
         while Last > 1 and then Figures (Last) = '0' loop
            Last := Last - 1;
         end loop;

         declare
            F : constant String := Figures (1 .. Last);
         begin
            --  Plain when it is near one, as a person writes 1500.0 and
            --  0.001; with an exponent otherwise, as 1e+30 is.

            if Power in 0 .. 20 then
               if F'Length <= Power + 1 then
                  return Sign & F & (Power + 1 - F'Length) * '0' & ".0";
               else
                  return Sign & F (1 .. Power + 1) & "."
                    & F (Power + 2 .. F'Last);
               end if;
            elsif Power in -7 .. -1 then
               return Sign & "0." & (-Power - 1) * '0' & F;
            else
               declare
                  P : constant String :=
                        Trim (Integer'Image (Power), Ada.Strings.Left);
               begin
                  return Sign & F (1 .. 1)
                    & (if F'Length > 1 then "." & F (2 .. F'Last) else "")
                    & "e" & (if Power > 0 then "+" & P else P);
               end;
            end if;
         end;
      end;
   end Double_Image;

   ---------------
   -- Double_Op --
   ---------------

   function Double_Op
     (Left  : Number;
      Op    : Character;
      Right : Number)
      return Number
   is
      L : constant Long_Float := To_Double (Left);
      R : constant Long_Float := To_Double (Right);
   begin
      return Checked_Inexact
        (case Op is
            when '+'    => L + R,
            when '-'    => L - R,
            when '*'    => L * R,
            when others => L / R);
   exception
      when Constraint_Error =>
         raise Constraint_Error with
           "inexact overflow: past what a double holds";
   end Double_Op;

   ------------
   -- Encode --
   ------------

   function Encode
     (VM : Raven_VM'Class;
      N  : Number)
      return Object
   is
   begin
      case N.Kind is
         when Fixnum =>
            return Raven.Objects.To_Object (N.Value);

         when Flonum =>

            --  The immediate when it holds the double exactly, which is
            --  most of the doubles a program writes, and a box when it
            --  does not.

            if Raven.Objects.Fits_Immediate (N.Inexact) then
               return Raven.Objects.To_Object (Float (N.Inexact));
            else
               return VM.New_Flonum (N.Inexact);
            end if;

         when Ratnum =>

            --  Numerator and denominator are each an integer, and either
            --  may be a bignum, which is made in the heap and may collect.
            --  The numerator is held on the machine's stack while the
            --  denominator is made, so that a collection then moves it
            --  and it is still where it is afterwards; and the cons that
            --  pairs them keeps both across the one it may make.

            declare
               Held : constant Object :=
                        Encode (VM, Normal (Numerator (N.Ratio)));
            begin
               VM.Hold_Object (Held);
            end;

            declare
               Lower : constant Object :=
                         Encode (VM, Normal (Denominator (N.Ratio)));
               Upper : constant Object := VM.Release_Object;
            begin
               return VM.New_Ratnum (Upper, Lower);
            end;

         when Bignum =>
            null;
      end case;

      --  The magnitude a byte at a time, least significant first, which
      --  is the order the block keeps them in.

      declare
         Magnitude : Big_Integer := abs N.Big;
         Count     : Natural := 0;
      begin
         while Magnitude > To_Big_Integer (0) loop
            Magnitude := Magnitude / Byte_Base;
            Count := Count + 1;
         end loop;

         declare
            Result : constant Object :=
                       VM.New_Bignum (Count, N.Big < To_Big_Integer (0));
         begin
            --  Nothing below makes anything, so Result is where it was
            --  made until it is handed back.

            Magnitude := abs N.Big;

            for Index in 0 .. Count - 1 loop
               VM.Set_Vector_Element
                 (Result, Index,
                  Raven.Objects.To_Object
                    (To_Integer (Magnitude rem Byte_Base)));
               Magnitude := Magnitude / Byte_Base;
            end loop;

            return Result;
         end;
      end;
   end Encode;

   -----------
   -- Equal --
   -----------

   --  An exact number and an inexact one are compared as doubles, which
   --  is what (= 2 2.0) asks.  Otherwise normal numbers of different
   --  representations are never equal.

   function Equal (Left, Right : Number) return Boolean
   is (if Either_Inexact (Left, Right)
       then To_Double (Left) = To_Double (Right)
       elsif Either_Ratnum (Left, Right)
       then To_Real (Left) = To_Real (Right)
       elsif Both_Fixnums (Left, Right)
       then Left.Value = Right.Value
       elsif Left.Kind = Right.Kind
       then Left.Big = Right.Big
       else False);

   ---------
   -- Eqv --
   ---------

   function Eqv (Left, Right : Number) return Boolean
   is (Is_Exact (Left) = Is_Exact (Right) and then Equal (Left, Right));

   -----------
   -- Image --
   -----------

   function Image
     (N    : Number;
      Base : Radix := 10)
      return String
   is
      Digits_Of : constant String := "0123456789abcdef";
      Big_Base  : constant Big_Integer := To_Big_Integer (Base);
      Magnitude : Big_Integer;

      function Rest return String;

      ----------
      -- Rest --
      ----------

      --  The digits of what is left of the magnitude, a buffer's worth
      --  at a time from the least significant end, so that a number of
      --  any length is written without a limit on how long.

      function Rest return String is
         Buffer : String (1 .. 256);
         First  : Positive := Buffer'Last + 1;
      begin
         while Magnitude > To_Big_Integer (0)
           and then First > Buffer'First
         loop
            First := First - 1;
            Buffer (First) :=
              Digits_Of (To_Integer (Magnitude rem Big_Base) + 1);
            Magnitude := Magnitude / Big_Base;
         end loop;

         declare
            Tail : constant String := Buffer (First .. Buffer'Last);
         begin
            return (if Magnitude > To_Big_Integer (0)
                    then Rest & Tail
                    else Tail);
         end;
      end Rest;

   begin
      if N.Kind = Flonum then
         return Double_Image (N.Inexact);
      elsif N.Kind = Ratnum then
         return Image (Normal (Numerator (N.Ratio)), Base)
           & "/" & Image (Normal (Denominator (N.Ratio)), Base);
      end if;

      Magnitude := abs To_Big (N);

      if Magnitude = To_Big_Integer (0) then
         return "0";
      end if;

      return (if To_Big (N) < To_Big_Integer (0) then "-" else "") & Rest;
   end Image;

   ----------------
   -- Inexact_Of --
   ----------------

   function Inexact_Of (Value : Long_Float) return Number
   is (Checked_Inexact (Value));

   ------------------
   -- Integer_Root --
   ------------------

   function Integer_Root (N : Big_Integer) return Big_Integer is
      Text : constant String := To_String (N);
      X    : Big_Integer;
      Y    : Big_Integer;
   begin
      if N < To_Big_Integer (2) then
         return N;
      end if;

      --  Ten to half as many digits as N has, rounded up, is at least
      --  its root, and Newton's method comes down from above to it.

      X := To_Big_Integer (10) ** Natural ((Text'Length + 1) / 2);

      loop
         Y := (X + N / X) / To_Big_Integer (2);
         exit when Y >= X;
         X := Y;
      end loop;

      return X;
   end Integer_Root;

   -------------------
   -- Is_Arithmetic --
   -------------------

   function Is_Arithmetic (X : Object) return Boolean
   is (Raven.Objects.Is_Number (X));

   --------------
   -- Is_Exact --
   --------------

   function Is_Exact (N : Number) return Boolean
   is (N.Kind /= Flonum);

   --------------
   -- Is_Whole --
   --------------

   function Is_Whole (N : Number) return Boolean
   is (case N.Kind is
          when Fixnum | Bignum => True,
          when Ratnum          => False,
          when Flonum          =>
             N.Inexact = Long_Float'Truncation (N.Inexact));

   -------------------
   -- Less_Or_Equal --
   -------------------

   function Less_Or_Equal (Left, Right : Number) return Boolean
   is (if Either_Inexact (Left, Right)
       then To_Double (Left) <= To_Double (Right)
       elsif Either_Ratnum (Left, Right)
       then To_Real (Left) <= To_Real (Right)
       elsif Both_Fixnums (Left, Right)
       then Left.Value <= Right.Value
       else To_Big (Left) <= To_Big (Right));

   --------------
   -- Multiply --
   --------------

   function Multiply (Left, Right : Number) return Number
   is (if Either_Inexact (Left, Right)
       then Double_Op (Left, '*', Right)
       elsif Either_Ratnum (Left, Right)
       then Normal (To_Real (Left) * To_Real (Right))
       elsif Both_Fixnums (Left, Right)
       then Normal (Widened (Left) * Widened (Right))
       else Normal (To_Big (Left) * To_Big (Right)));

   ------------
   -- Normal --
   ------------

   function Normal (Wide : Long_Long_Integer) return Number
   is (if Wide in Long_Long_Integer (Fixnum_Value'First)
                .. Long_Long_Integer (Fixnum_Value'Last)
       then (Kind => Fixnum, Value => Fixnum_Value (Wide))
       else (Kind => Bignum, Big => Wide_Conversions.To_Big_Integer (Wide)));

   ------------
   -- Normal --
   ------------

   function Normal (Big : Big_Integer) return Number
   is (if In_Range (Big,
                    To_Big_Integer (Fixnum_Value'First),
                    To_Big_Integer (Fixnum_Value'Last))
       then (Kind => Fixnum, Value => To_Integer (Big))
       else (Kind => Bignum, Big => Big));

   ------------
   -- Normal --
   ------------

   function Normal (Real : Big_Real) return Number
   is (if Denominator (Real) = To_Big_Integer (1)
       then Normal (Numerator (Real))
       else (Kind => Ratnum, Ratio => Real));

   ---------------
   -- Numerator --
   ---------------

   function Numerator (N : Number) return Number
   is (case N.Kind is
          when Fixnum | Bignum => N,
          when Ratnum          => Normal (Numerator (N.Ratio)),
          when Flonum          => To_Inexact (Numerator (To_Exact (N))));

   -----------
   -- Power --
   -----------

   function Power (Base, Exponent : Number) return Number is
      B : constant Long_Float := To_Double (Base);
      E : constant Long_Float := To_Double (Exponent);
   begin
      if B < 0.0 and then E /= Long_Float'Truncation (E) then
         raise Constraint_Error with
           "expt: " & Image (Base) & " to the power " & Image (Exponent)
           & " is a complex number, and raven has none";
      elsif B = 0.0 then
         return (if E = 0.0 then Checked_Inexact (1.0)
                 elsif E > 0.0 then Checked_Inexact (0.0)
                 else raise Constraint_Error with "expt: divide by zero");
      end if;

      return Checked_Inexact
        (Ada.Numerics.Long_Elementary_Functions."**" (B, E));
   exception
      when Ada.Numerics.Argument_Error =>
         raise Constraint_Error with
           "expt: " & Image (Base) & " to the power " & Image (Exponent)
           & " has no answer a double holds";
   end Power;

   --------------
   -- Quotient --
   --------------

   function Quotient (Left, Right : Number) return Number is
   begin
      if Equal (Right, (Kind => Fixnum, Value => 0)) then
         raise Constraint_Error with "divide by zero";
      end if;

      return (if Either_Inexact (Left, Right)
              then Checked_Inexact
                     (Long_Float'Truncation
                        (To_Double (Left) / To_Double (Right)))
              elsif Both_Fixnums (Left, Right)
              then Normal (Widened (Left) / Widened (Right))
              else Normal (Big_Integer'(To_Big (Left) / To_Big (Right))));
   end Quotient;

   ----------
   -- Read --
   ----------

   procedure Read
     (Text  : String;
      Base  : Radix;
      N     : out Number;
      Valid : out Boolean)
   is
      Here     : Positive := Text'First;
      In_Base  : Radix := Base;
      Negative : Boolean := False;
      Result   : Big_Integer := To_Big_Integer (0);
      Seen     : Boolean := False;

      --  After a slash, the digits go to the denominator, and there have
      --  to be some.

      Slash       : Boolean := False;
      Lower       : Big_Integer := To_Big_Integer (0);
      Seen_Lower  : Boolean := False;

      procedure Take_Sign;

      ---------------
      -- Take_Sign --
      ---------------

      procedure Take_Sign is
      begin
         if Here <= Text'Last
           and then (Text (Here) = '+' or else Text (Here) = '-')
         then
            Negative := Text (Here) = '-';
            Here := Here + 1;
         end if;
      end Take_Sign;

   begin
      N := (Kind => Fixnum, Value => 0);
      Valid := False;

      --  The sign may come before the prefix or after it: -13, #x1F and
      --  #x-1F are each one number, as the reader takes them.

      Take_Sign;

      if Here < Text'Last and then Text (Here) = '#' then
         case Text (Here + 1) is
            when 'b' | 'B' => In_Base := 2;
            when 'o' | 'O' => In_Base := 8;
            when 'd' | 'D' => In_Base := 10;
            when 'x' | 'X' => In_Base := 16;
            when others    => return;
         end case;
         Here := Here + 2;
         Take_Sign;
      end if;

      while Here <= Text'Last loop
         declare
            Ch    : constant Character := Text (Here);
            Digit : Integer := -1;
         begin
            case Ch is
               when '0' .. '9' =>
                  Digit := Character'Pos (Ch) - Character'Pos ('0');
               when 'a' .. 'f' =>
                  Digit := Character'Pos (Ch) - Character'Pos ('a') + 10;
               when 'A' .. 'F' =>
                  Digit := Character'Pos (Ch) - Character'Pos ('A') + 10;
               when others =>
                  null;
            end case;

            if Ch = '/' and then Seen and then not Slash then
               Slash := True;
            elsif Digit not in 0 .. In_Base - 1 then
               return;
            elsif Slash then
               Lower := Lower * To_Big_Integer (In_Base)
                 + To_Big_Integer (Digit);
               Seen_Lower := True;
            else
               Result := Result * To_Big_Integer (In_Base)
                 + To_Big_Integer (Digit);
               Seen := True;
            end if;
         end;
         Here := Here + 1;
      end loop;

      if not Seen or else Slash /= Seen_Lower then
         return;
      end if;

      if Negative then
         Result := -Result;
      end if;

      if not Slash then
         N := Normal (Result);
      elsif Lower = To_Big_Integer (0) then
         return;
      else
         N := Normal (Big_Real'(Result / Lower));
      end if;

      Valid := True;
   end Read;

   ------------------
   -- Read_Decimal --
   ------------------

   procedure Read_Decimal
     (Text  : String;
      N     : out Number;
      Valid : out Boolean)
   is
      Sign       : constant String :=
                     (if Text'Length > 0
                        and then (Text (Text'First) = '-'
                                  or else Text (Text'First) = '+')
                      then Text (Text'First .. Text'First)
                      else "");
      Rest       : constant String :=
                     Text (Text'First + Sign'Length .. Text'Last);
      Exponent   : Natural := 0;
      Seen_Digit : Boolean := False;
      Point      : Boolean := False;
   begin
      N := (Kind => Fixnum, Value => 0);
      Valid := False;

      --  Digits, at most one point, and an exponent after them; nothing
      --  else.  Which is decided before Ada is asked, so that what it
      --  would take and R7RS would not is not taken either.

      for I in Rest'Range loop
         case Rest (I) is
            when '0' .. '9' =>
               Seen_Digit := True;
            when '.' =>
               if Point or else Exponent /= 0 then
                  return;
               end if;
               Point := True;
            when 'e' | 'E' =>
               if Exponent /= 0
                 or else not Seen_Digit
                 or else I = Rest'Last
               then
                  return;
               end if;
               Exponent := I;
            when '+' | '-' =>
               if Exponent = 0 or else I /= Exponent + 1 then
                  return;
               end if;
            when others =>
               return;
         end case;
      end loop;

      if not Seen_Digit or else not (Point or else Exponent /= 0) then
         return;
      end if;

      declare
         Last     : constant Natural :=
                      (if Exponent = 0 then Rest'Last else Exponent - 1);
         Mantissa : constant String := Rest (Rest'First .. Last);
         Whole    : constant String :=
                      (if Mantissa'Length = 0
                         or else Mantissa (Mantissa'First) = '.'
                       then "0" & Mantissa
                       else Mantissa);
         Pointed  : constant String :=
                      (if not Point then Whole & ".0"
                       elsif Whole (Whole'Last) = '.' then Whole & "0"
                       else Whole);
         Power    : constant String :=
                      (if Exponent = 0 then ""
                       else "E" & Rest (Exponent + 1 .. Rest'Last));
      begin
         N := Checked_Inexact (Long_Float'Value (Sign & Pointed & Power));
         Valid := True;
      exception
         when Constraint_Error =>
            N := (Kind => Fixnum, Value => 0);
            Valid := False;
      end;
   end Read_Decimal;

   -------------
   -- Rounded --
   -------------

   function Rounded (N : Number; How : Rounding) return Number is
   begin
      if N.Kind in Fixnum | Bignum then
         return N;
      end if;

      --  A rational rounds to an exact integer.  Big_Integer's division
      --  truncates towards nought, and the denominator is positive, so
      --  the floor is the truncation or one below it, and the rest
      --  follows from the floor and what is left over.

      if N.Kind = Ratnum then
         declare
            Upper   : constant Big_Integer := Numerator (N.Ratio);
            Lower   : constant Big_Integer := Denominator (N.Ratio);
            Trunc   : constant Big_Integer := Upper / Lower;
            Floored : constant Big_Integer :=
                        (if Upper < To_Big_Integer (0) then Trunc - 1
                         else Trunc);
            Twice   : constant Big_Integer :=
                        2 * (Upper - Floored * Lower);
         begin
            return Normal
              (case How is
                  when Floor    => Floored,
                  when Ceiling  => Floored + 1,
                  when Truncate => Trunc,
                  when Round    =>
                    (if Twice < Lower then Floored
                     elsif Twice > Lower then Floored + 1
                     elsif Floored rem 2 = To_Big_Integer (0) then Floored
                     else Floored + 1));
         end;
      end if;

      return (Kind    => Flonum,
              Inexact =>
                (case How is
                    when Floor    => Long_Float'Floor (N.Inexact),
                    when Ceiling  => Long_Float'Ceiling (N.Inexact),
                    when Truncate => Long_Float'Truncation (N.Inexact),
                    when Round    =>
                      Long_Float'Unbiased_Rounding (N.Inexact)));
   end Rounded;

   -----------------
   -- Square_Root --
   -----------------

   function Square_Root (N : Number) return Number is

      --  The exact root of an exact integer that has one.

      function Exact_Root
        (Of_This : Big_Integer;
         Root    : out Big_Integer)
         return Boolean;

      ----------------
      -- Exact_Root --
      ----------------

      function Exact_Root
        (Of_This : Big_Integer;
         Root    : out Big_Integer)
         return Boolean
      is
      begin
         Root := Integer_Root (Of_This);
         return Root * Root = Of_This;
      end Exact_Root;

   begin
      if not Less_Or_Equal (Zero, N) then
         raise Constraint_Error with
           "sqrt: " & Image (N) & " has no real square root, and raven has"
           & " no complex numbers";
      end if;

      case N.Kind is
         when Fixnum | Bignum =>
            declare
               Root : Big_Integer;
            begin
               if Exact_Root (To_Big (N), Root) then
                  return Normal (Root);
               end if;
            end;

         when Ratnum =>
            declare
               Upper : Big_Integer;
               Lower : Big_Integer;
            begin
               if Exact_Root (Numerator (N.Ratio), Upper)
                 and then Exact_Root (Denominator (N.Ratio), Lower)
               then
                  return Normal (Big_Real'(Upper / Lower));
               end if;
            end;

         when Flonum =>
            null;
      end case;

      return Checked_Inexact
        (Ada.Numerics.Long_Elementary_Functions.Sqrt (To_Double (N)));
   end Square_Root;

   --------------
   -- Subtract --
   --------------

   function Subtract (Left, Right : Number) return Number
   is (if Either_Inexact (Left, Right)
       then Double_Op (Left, '-', Right)
       elsif Either_Ratnum (Left, Right)
       then Normal (To_Real (Left) - To_Real (Right))
       elsif Both_Fixnums (Left, Right)
       then Normal (Widened (Left) - Widened (Right))
       else Normal (To_Big (Left) - To_Big (Right)));

   ------------
   -- To_Big --
   ------------

   function To_Big (N : Number) return Big_Integer
   is (if N.Kind = Fixnum then To_Big_Integer (N.Value) else N.Big);

   ---------------
   -- To_Double --
   ---------------

   --  A bignum past what a double holds has no double, and says so.

   function To_Double (N : Number) return Long_Float is
   begin
      case N.Kind is
         when Fixnum =>
            return Long_Float (N.Value);
         when Flonum =>
            return N.Inexact;
         when Bignum =>
            return Long_Float'Value (To_String (N.Big));
         when Ratnum =>
            return Double_Conversions.From_Big_Real (N.Ratio);
      end case;
   exception
      when Constraint_Error =>
         raise Constraint_Error with
           "inexact overflow: " & Image (N)
           & " is past what a double holds";
   end To_Double;

   --------------
   -- To_Exact --
   --------------

   function To_Exact (N : Number) return Number is
   begin
      if Is_Exact (N) then
         return N;
      end if;

      --  A double that is not whole is the exact fraction it is, which
      --  is a dyadic one: (exact 0.5) is 1/2 and (exact 0.1) is the
      --  fraction nearest a tenth that a double holds.

      if not Is_Whole (N) then
         return Normal (Double_Conversions.To_Big_Real (N.Inexact));
      end if;

      --  A whole double is its significand times a power of two, and
      --  both are exact.  Below 2**62 it fits in a Long_Long_Integer and
      --  the conversion is direct.

      if abs N.Inexact < 2.0 ** 62 then
         return Normal (Long_Long_Integer (N.Inexact));
      end if;

      declare
         Fraction    : constant Long_Float :=
                         Long_Float'Fraction (N.Inexact);
         Significand : constant Long_Long_Integer :=
                         Long_Long_Integer
                           (Long_Float'Scaling
                              (Fraction, Long_Float'Machine_Mantissa));
         Power       : constant Natural :=
                         Long_Float'Exponent (N.Inexact)
                         - Long_Float'Machine_Mantissa;
      begin
         return Normal
           (Wide_Conversions.To_Big_Integer (Significand)
            * To_Big_Integer (2) ** Power);
      end;
   end To_Exact;

   ----------------
   -- To_Inexact --
   ----------------

   function To_Inexact (N : Number) return Number
   is (if Is_Exact (N) then Checked_Inexact (To_Double (N)) else N);

   -------------
   -- To_Real --
   -------------

   function To_Real (N : Number) return Big_Real
   is (case N.Kind is
          when Fixnum => To_Big_Real (To_Big_Integer (N.Value)),
          when Bignum => To_Big_Real (N.Big),
          when Ratnum => N.Ratio,
          when Flonum => raise Program_Error);

end Raven.Numbers;

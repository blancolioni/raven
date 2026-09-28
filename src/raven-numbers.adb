package body Raven.Numbers is

   package Wide_Conversions is
     new Signed_Conversions (Long_Long_Integer);

   Byte_Base : constant Big_Integer := To_Big_Integer (256);

   --  The Number an integer is, made normal: a fixnum when it fits, and
   --  a bignum when it does not.  Every operation's answer goes through
   --  one of these two, which is where normalisation is kept.

   function Normal (Wide : Long_Long_Integer) return Number;
   function Normal (Big : Big_Integer) return Number;

   --  Either kind as a Big_Integer, for an operation one of whose
   --  operands is a bignum.

   function To_Big (N : Number) return Big_Integer;

   function Both_Fixnums (Left, Right : Number) return Boolean
   is (Left.Kind = Fixnum and then Right.Kind = Fixnum);

   function Widened (N : Number) return Long_Long_Integer
   is (Long_Long_Integer (N.Value))
     with Pre => N.Kind = Fixnum;

   ---------
   -- Add --
   ---------

   function Add (Left, Right : Number) return Number
   is (if Both_Fixnums (Left, Right)
       then Normal (Widened (Left) + Widened (Right))
       else Normal (To_Big (Left) + To_Big (Right)));

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

   ------------
   -- Divide --
   ------------

   function Divide (Left, Right : Number) return Number is
   begin
      --  A bignum is never nought, so a zero divisor is a fixnum.

      if Right.Kind = Fixnum and then Right.Value = 0 then
         raise Constraint_Error with "divide by zero";
      end if;

      --  The one fixnum division that does not fit, the smallest by -1,
      --  is one past the largest and is a bignum like any other.

      return (if Both_Fixnums (Left, Right)
              then Normal (Widened (Left) / Widened (Right))
              else Normal (To_Big (Left) / To_Big (Right)));
   end Divide;

   ------------
   -- Encode --
   ------------

   function Encode
     (VM : Raven_VM'Class;
      N  : Number)
      return Object
   is
   begin
      if N.Kind = Fixnum then
         return Raven.Objects.To_Object (N.Value);
      end if;

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

   --  Normal numbers, so a fixnum and a bignum are never equal.

   function Equal (Left, Right : Number) return Boolean
   is (if Both_Fixnums (Left, Right)
       then Left.Value = Right.Value
       elsif Left.Kind = Right.Kind
       then Left.Big = Right.Big
       else False);

   ---------
   -- Eqv --
   ---------

   --  Every integer is exact, so this is Equal until there is an
   --  inexact number to tell it from.

   function Eqv (Left, Right : Number) return Boolean
   is (Equal (Left, Right));

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
      Magnitude : Big_Integer := abs To_Big (N);

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
      if Magnitude = To_Big_Integer (0) then
         return "0";
      end if;

      return (if To_Big (N) < To_Big_Integer (0) then "-" else "") & Rest;
   end Image;

   -------------------
   -- Is_Arithmetic --
   -------------------

   --  A float is a number and not yet something arithmetic can do
   --  anything with (#103), so it is not here.

   function Is_Arithmetic (X : Object) return Boolean
   is (Raven.Objects.Is_Integer (X) or else Raven.Objects.Is_Bignum (X));

   -------------------
   -- Less_Or_Equal --
   -------------------

   function Less_Or_Equal (Left, Right : Number) return Boolean
   is (if Both_Fixnums (Left, Right)
       then Left.Value <= Right.Value
       else To_Big (Left) <= To_Big (Right));

   --------------
   -- Multiply --
   --------------

   function Multiply (Left, Right : Number) return Number
   is (if Both_Fixnums (Left, Right)
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

            if Digit not in 0 .. In_Base - 1 then
               return;
            end if;

            Result := Result * To_Big_Integer (In_Base)
              + To_Big_Integer (Digit);
            Seen := True;
         end;
         Here := Here + 1;
      end loop;

      if Seen then
         N := Normal (if Negative then -Result else Result);
         Valid := True;
      end if;
   end Read;

   --------------
   -- Subtract --
   --------------

   function Subtract (Left, Right : Number) return Number
   is (if Both_Fixnums (Left, Right)
       then Normal (Widened (Left) - Widened (Right))
       else Normal (To_Big (Left) - To_Big (Right)));

   ------------
   -- To_Big --
   ------------

   function To_Big (N : Number) return Big_Integer
   is (if N.Kind = Fixnum then To_Big_Integer (N.Value) else N.Big);

end Raven.Numbers;

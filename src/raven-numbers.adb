package body Raven.Numbers is

   --  The answer to Left Op Right, worked out wide and then made a
   --  normal Number.  Two fixnums are 29 bits and a sign, so a sum, a
   --  difference and a product all fit in Long_Long_Integer with room
   --  over, and whether the answer fits in a fixnum is a comparison.
   --  One that does not is where a bignum will be made (#102); until
   --  then it is refused, and the refusal says what was asked.

   function Normal
     (Wide  : Long_Long_Integer;
      Left  : Number;
      Op    : String;
      Right : Number)
      return Number;

   function Widened (N : Number) return Long_Long_Integer
   is (Long_Long_Integer (N.Value));

   ---------
   -- Add --
   ---------

   function Add (Left, Right : Number) return Number
   is (Normal (Widened (Left) + Widened (Right), Left, "+", Right));

   ------------
   -- Decode --
   ------------

   function Decode (X : Object) return Number
   is ((Kind => Fixnum, Value => Raven.Objects.To_Integer (X)));

   ------------
   -- Divide --
   ------------

   function Divide (Left, Right : Number) return Number is
   begin
      if Right.Value = 0 then
         raise Constraint_Error with "divide by zero";
      end if;

      --  One division overflows: the smallest integer by -1, whose
      --  answer is one past the largest.

      return Normal (Widened (Left) / Widened (Right), Left, "/", Right);
   end Divide;

   ------------
   -- Encode --
   ------------

   function Encode (N : Number) return Object
   is (Raven.Objects.To_Object (N.Value));

   -----------
   -- Image --
   -----------

   function Image (N : Number) return String is
      S : constant String := N.Value'Image;
   begin
      return (if S (S'First) = ' ' then S (S'First + 1 .. S'Last) else S);
   end Image;

   -------------------
   -- Is_Arithmetic --
   -------------------

   --  A float is a number and not yet something arithmetic can do
   --  anything with (#103), so it is not here.

   function Is_Arithmetic (X : Object) return Boolean
   is (Raven.Objects.Is_Integer (X));

   -------------------
   -- Less_Or_Equal --
   -------------------

   function Less_Or_Equal (Left, Right : Number) return Boolean
   is (Left.Value <= Right.Value);

   --------------
   -- Multiply --
   --------------

   function Multiply (Left, Right : Number) return Number
   is (Normal (Widened (Left) * Widened (Right), Left, "*", Right));

   ------------
   -- Normal --
   ------------

   function Normal
     (Wide  : Long_Long_Integer;
      Left  : Number;
      Op    : String;
      Right : Number)
      return Number
   is
      What : constant String :=
               "integer overflow: " & Image (Left) & " " & Op & " "
               & Image (Right) & " is past the ";
   begin
      if Wide > Long_Long_Integer (Fixnum_Value'Last) then
         raise Constraint_Error with
           What & "largest integer raven holds, "
           & Image ((Kind => Fixnum, Value => Fixnum_Value'Last));
      elsif Wide < Long_Long_Integer (Fixnum_Value'First) then
         raise Constraint_Error with
           What & "smallest integer raven holds, "
           & Image ((Kind => Fixnum, Value => Fixnum_Value'First));
      end if;

      return (Kind => Fixnum, Value => Fixnum_Value (Wide));
   end Normal;

   --------------
   -- Subtract --
   --------------

   function Subtract (Left, Right : Number) return Number
   is (Normal (Widened (Left) - Widened (Right), Left, "-", Right));

end Raven.Numbers;

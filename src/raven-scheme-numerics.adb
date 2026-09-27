with Raven.Objects;

package body Raven.Scheme.Numerics is

   procedure Add (VM : Raven_VM);
   procedure Divide (VM : Raven_VM);
   procedure Leq (VM : Raven_VM);
   procedure Multiply (VM : Raven_VM);
   procedure Sub (VM : Raven_VM);

   --  The answer to X Op Y, worked out wide: the operands are 29 bits
   --  and a sign, so a sum, a difference and a product all fit in
   --  Long_Long_Integer with room over, and whether the answer fits in
   --  an object is a comparison rather than a guess.  One that does not
   --  is refused, and the refusal says what was asked.  This used to be
   --  done in Integer and handed to Set_Slot, which with contracts on
   --  was an assertion out of the machine and with them off was the
   --  number shifted and its top bits lost.
   --
   --  Every place that raises here is a place that will make a bignum
   --  once there are bignums (#102).

   function Checked
     (X, Y   : Integer;
      Op     : String;
      Result : Long_Long_Integer)
      return Integer;

   ---------
   -- Add --
   ---------

   procedure Add (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot
        (1,
         Checked
           (X, Y, "+", Long_Long_Integer (X) + Long_Long_Integer (Y)));
   end Add;

   -------------
   -- Checked --
   -------------

   function Checked
     (X, Y   : Integer;
      Op     : String;
      Result : Long_Long_Integer)
      return Integer
   is
      function Image (N : Long_Long_Integer) return String;

      -----------
      -- Image --
      -----------

      function Image (N : Long_Long_Integer) return String is
         S : constant String := N'Image;
      begin
         return (if S (S'First) = ' ' then S (S'First + 1 .. S'Last) else S);
      end Image;

   begin
      if Result > Raven.Objects.Max_Integer then
         raise Constraint_Error with
           "integer overflow: " & Image (Long_Long_Integer (X)) & " " & Op
           & " " & Image (Long_Long_Integer (Y)) & " is past"
           & " the largest integer raven holds, "
           & Image (Raven.Objects.Max_Integer);
      elsif Result < Raven.Objects.Min_Integer then
         raise Constraint_Error with
           "integer overflow: " & Image (Long_Long_Integer (X)) & " " & Op
           & " " & Image (Long_Long_Integer (Y)) & " is past"
           & " the smallest integer raven holds, "
           & Image (Raven.Objects.Min_Integer);
      end if;

      return Integer (Result);
   end Checked;

   ------------
   -- Divide --
   ------------

   procedure Divide (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      --  Every number here is an integer, and R7RS asks for an exact
      --  rational: (/ 7 2) is 7/2 and not 3.  Until there is a tower
      --  to answer with, this divides and throws the remainder away,
      --  which is the answer a reader of (/ 6 2) expects and not the
      --  one a reader of (/ 7 2) does.
      --
      --  One division overflows: the smallest integer by -1, whose
      --  answer is one past the largest.

      if Y = 0 then
         raise Constraint_Error with "divide by zero";
      end if;

      VM.Set_Slot
        (1,
         Checked
           (X, Y, "/", Long_Long_Integer (X) / Long_Long_Integer (Y)));
   end Divide;

   ---------
   -- Leq --
   ---------

   procedure Leq (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, X <= Y);
   end Leq;

   --------------------------
   -- Load_Numeric_Library --
   --------------------------

   procedure Load_Numeric_Library
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class)
   is
   begin
      Evaluator.Bind_Foreign_Function
        ("raven-add", Add'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-leq", Leq'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-sub", Sub'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-mul", Multiply'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-div", Divide'Access, 2);
   end Load_Numeric_Library;

   --------------
   -- Multiply --
   --------------

   procedure Multiply (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot
        (1,
         Checked
           (X, Y, "*", Long_Long_Integer (X) * Long_Long_Integer (Y)));
   end Multiply;

   ---------
   -- Sub --
   ---------

   procedure Sub (VM : Raven_VM) is
      X : constant Integer := VM.Get_Slot (1);
      Y : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot
        (1,
         Checked
           (X, Y, "-", Long_Long_Integer (X) - Long_Long_Integer (Y)));
   end Sub;

end Raven.Scheme.Numerics;

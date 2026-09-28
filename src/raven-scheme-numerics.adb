with Raven.Numbers;
with Raven.Objects;

package body Raven.Scheme.Numerics is

   --  The five arithmetic primitives, and everything the library's
   --  arithmetic is written on.  Each does three things and nothing
   --  else: decode its operands, ask Raven.Numbers for the answer, and
   --  encode it.  What a number is and what an operation does with one
   --  is all there, so that a new kind of number is a change there and
   --  not here.

   procedure Add (VM : Raven_VM);
   procedure Divide (VM : Raven_VM);
   procedure Leq (VM : Raven_VM);

   --  = and the number half of eqv?, which were identity.  They are the
   --  machine's now, because identity stops being equality as soon as a
   --  number can be boxed: two equal bignums are two objects.

   procedure Num_Eq (VM : Raven_VM);
   procedure Num_Eqv (VM : Raven_VM);
   procedure Multiply (VM : Raven_VM);
   procedure Sub (VM : Raven_VM);

   --  The number in this slot, or an error naming the procedure and
   --  what it was given.  It was a precondition on Get_Slot, so a
   --  float or a symbol handed to + was an assertion out of the machine.

   function Operand
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Raven.Numbers.Number;

   ---------
   -- Add --
   ---------

   procedure Add (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "+", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "+", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (Raven.Numbers.Add (Left, Right)));
   end Add;

   ------------
   -- Divide --
   ------------

   --  Every number here is an integer, and R7RS asks for an exact
   --  rational: (/ 7 2) is 7/2 and not 3.  Until there is a tower to
   --  answer with, this divides and throws the remainder away, which is
   --  the answer a reader of (/ 6 2) expects and not the one a reader of
   --  (/ 7 2) does.

   procedure Divide (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "/", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "/", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (Raven.Numbers.Divide (Left, Right)));
   end Divide;

   ---------
   -- Leq --
   ---------

   procedure Leq (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "comparison", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "comparison", 2);
   begin
      VM.Set_Slot (1, Raven.Numbers.Less_Or_Equal (Left, Right));
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
      Evaluator.Bind_Foreign_Function
        ("raven-num-eq", Num_Eq'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-num-eqv", Num_Eqv'Access, 2);
   end Load_Numeric_Library;

   --------------
   -- Multiply --
   --------------

   procedure Multiply (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "*", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "*", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (Raven.Numbers.Multiply (Left, Right)));
   end Multiply;

   ------------
   -- Num_Eq --
   ------------

   procedure Num_Eq (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
      Y : constant Object := VM.Get_Slot (2);
   begin
      --  A float is a number that arithmetic cannot take yet (#103), and
      --  = on two of them was identity, which for an immediate float is
      --  right within the type and wrong across it: (= 1.5 1.5) is #t
      --  and (= 2.0 2) is #f.  That much is kept as it was until floats
      --  go through the seam and = can say #t to the second.

      if Raven.Objects.Is_Float (X) or else Raven.Objects.Is_Float (Y) then
         if not Raven.Objects.Is_Number (X) then
            raise Constraint_Error with
              "=: not a number: " & Encode (VM.Display (X));
         elsif not Raven.Objects.Is_Number (Y) then
            raise Constraint_Error with
              "=: not a number: " & Encode (VM.Display (Y));
         end if;

         VM.Set_Slot (1, Boolean'(X = Y));
         return;
      end if;

      declare
         Left  : constant Raven.Numbers.Number := Operand (VM, "=", 1);
         Right : constant Raven.Numbers.Number := Operand (VM, "=", 2);
      begin
         VM.Set_Slot (1, Raven.Numbers.Equal (Left, Right));
      end;
   end Num_Eq;

   -------------
   -- Num_Eqv --
   -------------

   --  Two numbers, as eqv? asks about them.  Anything else is eq?'s
   --  question, and the library asks it there; this is only reached with
   --  two numbers.  A float is compared as the word it is, which for an
   --  immediate float is what eqv? means.

   procedure Num_Eqv (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
      Y : constant Object := VM.Get_Slot (2);
   begin
      if Raven.Numbers.Is_Arithmetic (X)
        and then Raven.Numbers.Is_Arithmetic (Y)
      then
         VM.Set_Slot
           (1,
            Raven.Numbers.Eqv
              (Raven.Numbers.Decode (X), Raven.Numbers.Decode (Y)));
      else
         VM.Set_Slot (1, Boolean'(X = Y));
      end if;
   end Num_Eqv;

   -------------
   -- Operand --
   -------------

   function Operand
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Raven.Numbers.Number
   is
      X : constant Object := VM.Get_Slot (Slot);
   begin
      --  A float is a number, and saying otherwise would be wrong; it
      --  is one arithmetic cannot take yet (#103).

      if Raven.Objects.Is_Float (X) then
         raise Constraint_Error with
           Name & ": raven has no arithmetic on floats yet: "
           & Encode (VM.Display (X));
      elsif not Raven.Numbers.Is_Arithmetic (X) then
         raise Constraint_Error with
           Name & ": not a number: " & Encode (VM.Display (X));
      end if;

      return Raven.Numbers.Decode (X);
   end Operand;

   ---------
   -- Sub --
   ---------

   procedure Sub (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "-", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "-", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (Raven.Numbers.Subtract (Left, Right)));
   end Sub;

end Raven.Scheme.Numerics;

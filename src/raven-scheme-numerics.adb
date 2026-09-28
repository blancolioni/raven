with Raven.Numbers;
with Raven.Objects;
with Raven.Strings;

package body Raven.Scheme.Numerics is

   --  The arithmetic primitives, and everything the library's
   --  arithmetic is written on.  Each does three things and nothing
   --  else: decode its operands, ask Raven.Numbers for the answer, and
   --  encode it.  What a number is and what an operation does with one
   --  is all there, so that a new kind of number is a change there and
   --  not here.

   procedure Add (VM : Raven_VM);
   procedure Divide (VM : Raven_VM);
   procedure Leq (VM : Raven_VM);
   procedure Multiply (VM : Raven_VM);
   procedure Sub (VM : Raven_VM);

   --  = and the number half of eqv?, which were identity.  They are the
   --  machine's, because identity stops being equality as soon as a
   --  number can be boxed: two equal bignums are two objects.

   procedure Num_Eq (VM : Raven_VM);
   procedure Num_Eqv (VM : Raven_VM);

   --  Exactness (#103): whether a number is exact, and the number as
   --  the other kind.

   procedure Is_Exact (VM : Raven_VM);
   procedure To_Exact (VM : Raven_VM);
   procedure To_Inexact (VM : Raven_VM);

   --  floor, ceiling, truncate and round, by the Rounding in slot 2's
   --  position.  They were the identity, which is right for an integer
   --  and wrong for a float.

   procedure Round (VM : Raven_VM);

   --  Integer division, which truncate-quotient and so quotient,
   --  remainder and modulo are written on: / is exact division now, and
   --  (/ 7 2) is 7/2.

   procedure Quotient (VM : Raven_VM);

   --  A rational's parts (#104).

   procedure Numerator (VM : Raven_VM);
   procedure Denominator (VM : Raven_VM);

   --  What (scheme inexact) is written on (#105), and a real power for
   --  expt: the square root, the elementary function whose position in
   --  Raven.Numbers.Elementary is in slot 2, atan of two arguments, and
   --  a number to a power that is not an exact integer.

   procedure Square_Root (VM : Raven_VM);
   procedure Integer_Square_Root (VM : Raven_VM);
   procedure Elementary (VM : Raven_VM);
   procedure Arctangent (VM : Raven_VM);
   procedure Power (VM : Raven_VM);

   --  A number written out and read back, in radix 2, 8, 10 or 16.

   procedure Number_To_String (VM : Raven_VM);
   procedure String_To_Number (VM : Raven_VM);

   --  The number in this slot, or an error naming the procedure and
   --  what it was given.

   function Operand
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Raven.Numbers.Number;

   --  The radix in this slot, or an error naming the procedure for one
   --  R7RS does not have.

   function Radix_In
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Raven.Numbers.Radix;

   ---------
   -- Add --
   ---------

   procedure Add (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "+", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "+", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Add (Left, Right)));
   end Add;

   ----------------
   -- Arctangent --
   ----------------

   procedure Arctangent (VM : Raven_VM) is
      Y : constant Raven.Numbers.Number := Operand (VM, "atan", 1);
      X : constant Raven.Numbers.Number := Operand (VM, "atan", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Arctangent (Y, X)));
   end Arctangent;

   -----------------
   -- Denominator --
   -----------------

   procedure Denominator (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Encode
           (VM, Raven.Numbers.Denominator (Operand (VM, "denominator", 1))));
   end Denominator;

   ------------
   -- Divide --
   ------------

   --  Exact for exact operands, so (/ 7 2) is 7/2 and (/ 6 2) the
   --  integer 3; it threw the remainder away while there were no exact
   --  fractions.  A division with an inexact operand is the double it
   --  comes to: (/ 7 2.0) is 3.5.

   procedure Divide (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "/", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "/", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Divide (Left, Right)));
   end Divide;

   ----------------
   -- Elementary --
   ----------------

   procedure Elementary (VM : Raven_VM) is
      How : constant Raven.Numbers.Elementary :=
              Raven.Numbers.Elementary'Val (Integer'(VM.Get_Slot (2)));
      N   : constant Raven.Numbers.Number :=
              Operand (VM, Raven.Numbers.Elementary'Image (How), 1);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Apply (How, N)));
   end Elementary;

   -------------------------
   -- Integer_Square_Root --
   -------------------------

   procedure Integer_Square_Root (VM : Raven_VM) is
      N : constant Raven.Numbers.Number :=
            Operand (VM, "exact-integer-sqrt", 1);
   begin
      if not (Raven.Numbers.Is_Exact (N) and then Raven.Numbers.Is_Whole (N))
      then
         raise Constraint_Error with
           "exact-integer-sqrt: not an exact integer: "
           & Raven.Numbers.Image (N);
      end if;

      VM.Set_Slot
        (1,
         Raven.Numbers.Encode (VM, Raven.Numbers.Integer_Square_Root (N)));
   end Integer_Square_Root;

   --------------
   -- Is_Exact --
   --------------

   procedure Is_Exact (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Is_Exact (Operand (VM, "exact?", 1)));
   end Is_Exact;

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
      Evaluator.Bind_Foreign_Function
        ("raven-number->string", Number_To_String'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-string->number", String_To_Number'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-exact?", Is_Exact'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-exact", To_Exact'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-inexact", To_Inexact'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-round", Round'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-quotient", Quotient'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-numerator", Numerator'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-denominator", Denominator'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-sqrt", Square_Root'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-exact-integer-sqrt", Integer_Square_Root'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("raven-elementary", Elementary'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-atan2", Arctangent'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-power", Power'Access, 2);
   end Load_Numeric_Library;

   --------------
   -- Multiply --
   --------------

   procedure Multiply (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "*", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "*", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Multiply (Left, Right)));
   end Multiply;

   ------------
   -- Num_Eq --
   ------------

   procedure Num_Eq (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "=", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "=", 2);
   begin
      VM.Set_Slot (1, Raven.Numbers.Equal (Left, Right));
   end Num_Eq;

   -------------
   -- Num_Eqv --
   -------------

   --  Two numbers, as eqv? asks about them.  Anything else is eq?'s
   --  question, and the library asks it there; this is only reached
   --  with two numbers.

   procedure Num_Eqv (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Eqv
           (Raven.Numbers.Decode (VM, VM.Get_Slot (1)),
            Raven.Numbers.Decode (VM, VM.Get_Slot (2))));
   end Num_Eqv;

   ----------------------
   -- Number_To_String --
   ----------------------

   procedure Number_To_String (VM : Raven_VM) is
      N    : constant Raven.Numbers.Number :=
               Operand (VM, "number->string", 1);
      Base : constant Raven.Numbers.Radix :=
               Radix_In (VM, "number->string", 2);
   begin
      if Base /= 10 and then not Raven.Numbers.Is_Exact (N) then
         raise Constraint_Error with
           "number->string: an inexact number is written in radix 10 only";
      end if;

      Raven.Strings.Write_String (VM, 1, Raven.Numbers.Image (N, Base));
   end Number_To_String;

   ---------------
   -- Numerator --
   ---------------

   procedure Numerator (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Encode
           (VM, Raven.Numbers.Numerator (Operand (VM, "numerator", 1))));
   end Numerator;

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
      if not Raven.Numbers.Is_Arithmetic (X) then
         raise Constraint_Error with
           Name & ": not a number: " & Encode (VM.Display (X));
      end if;

      return Raven.Numbers.Decode (VM, X);
   end Operand;

   -----------
   -- Power --
   -----------

   procedure Power (VM : Raven_VM) is
      Base     : constant Raven.Numbers.Number := Operand (VM, "expt", 1);
      Exponent : constant Raven.Numbers.Number := Operand (VM, "expt", 2);
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Encode (VM, Raven.Numbers.Power (Base, Exponent)));
   end Power;

   --------------
   -- Quotient --
   --------------

   procedure Quotient (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "quotient", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "quotient", 2);
   begin
      if not Raven.Numbers.Is_Whole (Left) then
         raise Constraint_Error with
           "quotient: not an integer: " & Raven.Numbers.Image (Left);
      elsif not Raven.Numbers.Is_Whole (Right) then
         raise Constraint_Error with
           "quotient: not an integer: " & Raven.Numbers.Image (Right);
      end if;

      VM.Set_Slot
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Quotient (Left, Right)));
   end Quotient;

   --------------
   -- Radix_In --
   --------------

   function Radix_In
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Raven.Numbers.Radix
   is
      X : constant Object := VM.Get_Slot (Slot);
   begin
      if not Raven.Objects.Is_Integer (X) then
         raise Constraint_Error with
           Name & ": not a radix: " & Encode (VM.Display (X));
      end if;

      declare
         Base : constant Integer := Raven.Objects.To_Integer (X);
      begin
         if Base not in 2 | 8 | 10 | 16 then
            raise Constraint_Error with
              Name & ": a radix is 2, 8, 10 or 16, not" & Base'Image;
         end if;
         return Base;
      end;
   end Radix_In;

   -----------
   -- Round --
   -----------

   procedure Round (VM : Raven_VM) is
      N   : constant Raven.Numbers.Number := Operand (VM, "rounding", 1);
      How : constant Integer := VM.Get_Slot (2);
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Encode
           (VM,
            Raven.Numbers.Rounded (N, Raven.Numbers.Rounding'Val (How))));
   end Round;

   -----------------
   -- Square_Root --
   -----------------

   procedure Square_Root (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Encode
           (VM, Raven.Numbers.Square_Root (Operand (VM, "sqrt", 1))));
   end Square_Root;

   ----------------------
   -- String_To_Number --
   ----------------------

   --  #f for what is not a number, as R7RS asks, rather than an error:
   --  asking whether some text is a number is what this is for.

   procedure String_To_Number (VM : Raven_VM) is
   begin
      if not Raven.Strings.Is_String (VM, 1) then
         raise Constraint_Error with
           "string->number: not a string: "
           & Encode (VM.Display (VM.Get_Slot (1)));
      end if;

      declare
         Text  : constant String := Raven.Strings.Get_String (VM, 1);
         Base  : constant Raven.Numbers.Radix :=
                   Radix_In (VM, "string->number", 2);
         N     : Raven.Numbers.Number;
         Valid : Boolean;
      begin
         Raven.Numbers.Read_Number (Text, Base, N, Valid);

         if Valid then
            VM.Set_Slot (1, Raven.Numbers.Encode (VM, N));
         else
            VM.Set_Slot (1, False);
         end if;
      end;
   end String_To_Number;

   ---------
   -- Sub --
   ---------

   procedure Sub (VM : Raven_VM) is
      Left  : constant Raven.Numbers.Number := Operand (VM, "-", 1);
      Right : constant Raven.Numbers.Number := Operand (VM, "-", 2);
   begin
      VM.Set_Slot
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Subtract (Left, Right)));
   end Sub;

   --------------
   -- To_Exact --
   --------------

   procedure To_Exact (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Encode
           (VM, Raven.Numbers.To_Exact (Operand (VM, "exact", 1))));
   end To_Exact;

   ----------------
   -- To_Inexact --
   ----------------

   procedure To_Inexact (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1,
         Raven.Numbers.Encode
           (VM, Raven.Numbers.To_Inexact (Operand (VM, "inexact", 1))));
   end To_Inexact;

end Raven.Scheme.Numerics;

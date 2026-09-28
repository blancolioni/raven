with Raven.Numbers;
with Raven.Objects;
with Raven.Strings;

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

   --  A number written out and read back, in radix 2, 8, 10 or 16.
   --  There were neither, so a bignum -- or any number -- could not be
   --  turned into text a program could hold.

   procedure Number_To_String (VM : Raven_VM);
   procedure String_To_Number (VM : Raven_VM);

   --  The radix in this slot: 10 when none was given, and an error
   --  naming the procedure for one R7RS does not have.

   function Radix_In
     (VM   : Raven_VM;
      Name : String;
      Slot : Slot_Index)
      return Raven.Numbers.Radix;

   --  A decimal with a point or an exponent, as a float, or False in
   --  Valid.  Ada's own reading of one wants a digit either side of the
   --  point and a point before the exponent, which R7RS does not.

   procedure Read_Float
     (Text  : String;
      Value : out Float;
      Valid : out Boolean);
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
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Add (Left, Right)));
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
        (1, Raven.Numbers.Encode (VM, Raven.Numbers.Divide (Left, Right)));
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
      Evaluator.Bind_Foreign_Function
        ("raven-number->string", Number_To_String'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("raven-string->number", String_To_Number'Access, 2);
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
              (Raven.Numbers.Decode (VM, X), Raven.Numbers.Decode (VM, Y)));
      else
         VM.Set_Slot (1, Boolean'(X = Y));
      end if;
   end Num_Eqv;

   ----------------------
   -- Number_To_String --
   ----------------------

   procedure Number_To_String (VM : Raven_VM) is
      X    : constant Object := VM.Get_Slot (1);
      Base : constant Raven.Numbers.Radix :=
               Radix_In (VM, "number->string", 2);
   begin
      if Raven.Numbers.Is_Arithmetic (X) then
         Raven.Strings.Write_String
           (VM, 1, Raven.Numbers.Image (Raven.Numbers.Decode (VM, X), Base));
      elsif Raven.Objects.Is_Float (X) then
         if Base /= 10 then
            raise Constraint_Error with
              "number->string: a float is written in radix 10 only";
         end if;
         Raven.Strings.Write_String (VM, 1, Encode (VM.Display (X)));
      else
         raise Constraint_Error with
           "number->string: not a number: " & Encode (VM.Display (X));
      end if;
   end Number_To_String;

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

      return Raven.Numbers.Decode (VM, X);
   end Operand;

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

   ----------------
   -- Read_Float --
   ----------------

   procedure Read_Float
     (Text  : String;
      Value : out Float;
      Valid : out Boolean)
   is
      Sign     : constant String :=
                   (if Text'Length > 0
                      and then (Text (Text'First) = '-'
                                or else Text (Text'First) = '+')
                    then Text (Text'First .. Text'First)
                    else "");
      Rest     : constant String :=
                   Text (Text'First + Sign'Length .. Text'Last);
      Exponent   : Natural := 0;
      Seen_Digit : Boolean := False;
      Point      : Boolean := False;
   begin
      Value := 0.0;
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
         Value := Float'Value (Sign & Pointed & Power);
         Valid := Raven.Objects.Is_Representable (Value);
      exception
         when Constraint_Error =>
            Valid := False;
      end;
   end Read_Float;

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
         Raven.Numbers.Read (Text, Base, N, Valid);

         if Valid then
            VM.Set_Slot (1, Raven.Numbers.Encode (VM, N));
            return;
         end if;

         if Base = 10 then
            declare
               Value : Float;
            begin
               Read_Float (Text, Value, Valid);
               if Valid then
                  VM.Set_Slot (1, Raven.Objects.To_Object (Value));
                  return;
               end if;
            end;
         end if;

         VM.Set_Slot (1, False);
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

end Raven.Scheme.Numerics;

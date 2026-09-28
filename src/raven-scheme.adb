with Raven.Numbers;
with Raven.Objects;
with Raven.Strings;
with Raven.Scheme.Numerics;
with Raven.Ports;
with Raven.Vectors;

package body Raven.Scheme is

   procedure Are_Equal (VM : Raven_VM);

   procedure Character_To_Integer (VM : Raven_VM);

   procedure Generate_Symbol (VM : Raven_VM);

   procedure Integer_To_Character (VM : Raven_VM);

   procedure Is_Character (VM : Raven_VM);

   procedure Is_Exact_Integer (VM : Raven_VM);

   procedure Is_Integer (VM : Raven_VM);

   procedure Is_Number (VM : Raven_VM);

   procedure Is_Procedure (VM : Raven_VM);

   procedure Is_Symbol (VM : Raven_VM);

   procedure Raise_Error (VM : Raven_VM);

   procedure Set_Car (VM : Raven_VM);

   procedure Set_Cdr (VM : Raven_VM);

   procedure String_To_Symbol (VM : Raven_VM);

   procedure Symbol_To_String (VM : Raven_VM);

   ---------------
   -- Are_Equal --
   ---------------

   procedure Are_Equal (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
      Y : constant Object := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, VM.Equal (X, Y));
   end Are_Equal;

   --------------------------
   -- Character_To_Integer --
   --------------------------

   procedure Character_To_Integer (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
   begin
      if not Raven.Objects.Is_Character (X) then
         raise Constraint_Error with
           "char->integer: not a character: " & Encode (VM.Display (X));
      end if;

      --  Qualified, because a code point is a universal integer and
      --  Set_Slot takes both an Integer and an Object.

      VM.Set_Slot
        (1,
         Integer (Wide_Wide_Character'Pos (Raven.Objects.To_Character (X))));
   end Character_To_Integer;

   ---------------------
   -- Generate_Symbol --
   ---------------------

   procedure Generate_Symbol (VM : Raven_VM) is
      Prefix : constant Object := VM.Get_Slot (1);
   begin
      --  A foreign function always gets as many arguments as it was
      --  bound with, so (gensym) arrives here with nil.

      if Raven.Objects.Is_Symbol (Prefix) then
         VM.Set_Slot (1, VM.New_Symbol (Encode (VM.Display (Prefix))));
      else
         VM.Set_Slot (1, VM.New_Symbol ("g"));
      end if;
   end Generate_Symbol;

   --------------------------
   -- Integer_To_Character --
   --------------------------

   procedure Integer_To_Character (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
   begin
      if not Raven.Objects.Is_Integer (X) then
         raise Constraint_Error with
           "integer->char: not an integer: " & Encode (VM.Display (X));
      end if;

      declare
         I : constant Integer := Raven.Objects.To_Integer (X);
      begin
         if I not in
           Wide_Wide_Character'Pos (Raven.Objects.Character_Value'First)
             .. Wide_Wide_Character'Pos (Raven.Objects.Character_Value'Last)
         then
            raise Constraint_Error with
              "integer->char: no character has the value" & I'Image;
         end if;

         VM.Set_Slot
           (1,
            Raven.Objects.To_Object (Wide_Wide_Character'Val (I)));
      end;
   end Integer_To_Character;

   ------------------
   -- Is_Character --
   ------------------

   procedure Is_Character (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Raven.Objects.Is_Character (VM.Get_Slot (1)));
   end Is_Character;

   ----------------------
   -- Is_Exact_Integer --
   ----------------------

   procedure Is_Exact_Integer (VM : Raven_VM) is
   begin
      VM.Set_Slot
        (1,
         Raven.Objects.Is_Integer (VM.Get_Slot (1))
           or else Raven.Objects.Is_Bignum (VM.Get_Slot (1)));
   end Is_Exact_Integer;

   ----------------
   -- Is_Integer --
   ----------------

   procedure Is_Integer (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
   begin
      --  R7RS asks integer? of the number and not of how it is held,
      --  so an inexact number that is a whole number is one: 2.0 is an
      --  integer, and is not an exact one.

      VM.Set_Slot
        (1,
         Raven.Numbers.Is_Arithmetic (X)
           and then Raven.Numbers.Is_Whole (Raven.Numbers.Decode (VM, X)));
   end Is_Integer;

   ---------------
   -- Is_Number --
   ---------------

   procedure Is_Number (VM : Raven_VM) is
   begin
      --  One mask and one compare over both numeric tags, because
      --  integer is 0 and float is 1 and nothing else has bit one
      --  clear.  It used to be the two questions asked separately.

      VM.Set_Slot (1, Raven.Objects.Is_Number (VM.Get_Slot (1)));
   end Is_Number;

   ------------------
   -- Is_Procedure --
   ------------------

   procedure Is_Procedure (VM : Raven_VM) is
      use Raven.Objects;
      X : constant Object := VM.Get_Slot (1);
   begin
      --  The two kinds there are: one written in scheme, which the
      --  machine makes, and one the host bound.  Neither could be
      --  asked about before -- a closure was a pair and answered to
      --  pair? along with every list.

      VM.Set_Slot (1, Is_Closure (X) or else Is_Foreign_Function (X));
   end Is_Procedure;

   ---------------
   -- Is_Symbol --
   ---------------

   procedure Is_Symbol (VM : Raven_VM) is
   begin
      VM.Set_Slot (1, Raven.Objects.Is_Symbol (VM.Get_Slot (1)));
   end Is_Symbol;

   --------------------------
   -- Load_Base_Primitives --
   --------------------------

   procedure Load_Base_Primitives
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class)
   is
   begin
      Evaluator.Bind_Foreign_Function
        ("equal?", Are_Equal'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("symbol?", Is_Symbol'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("gensym", Generate_Symbol'Access, 1);

      Evaluator.Bind_Foreign_Function
        ("error", Raise_Error'Access, 1);

      --  Things the machine could already do and offered no name for.
      --  None of them is a new idea: writing a cell is what RAP has
      --  always done, the symbol table already reads a name both ways,
      --  and a character is an immediate holding its own code point.

      Evaluator.Bind_Foreign_Function
        ("set-car!", Set_Car'Access, 2);
      Evaluator.Bind_Foreign_Function
        ("set-cdr!", Set_Cdr'Access, 2);

      Evaluator.Bind_Foreign_Function
        ("symbol->string", Symbol_To_String'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("string->symbol", String_To_Symbol'Access, 1);

      Evaluator.Bind_Foreign_Function
        ("char->integer", Character_To_Integer'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("integer->char", Integer_To_Character'Access, 1);

      Evaluator.Bind_Foreign_Function
        ("procedure?", Is_Procedure'Access, 1);

      Evaluator.Bind_Foreign_Function
        ("char?", Is_Character'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("integer?", Is_Integer'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("number?", Is_Number'Access, 1);
      Evaluator.Bind_Foreign_Function
        ("exact-integer?", Is_Exact_Integer'Access, 1);

      Raven.Scheme.Numerics.Load_Numeric_Library (Evaluator);
      Raven.Strings.Load_String_Library (Evaluator);
      Raven.Vectors.Load_Vector_Library (Evaluator);
      Raven.Ports.Load_Port_Library (Evaluator);
   end Load_Base_Primitives;

   -----------------
   -- Raise_Error --
   -----------------

   procedure Raise_Error (VM : Raven_VM) is
   begin
      raise Constraint_Error with
        Encode (VM.Display (VM.Get_Slot (1)));
   end Raise_Error;

   -------------
   -- Set_Car --
   -------------

   procedure Set_Car (VM : Raven_VM) is
      Pair : constant Object := VM.Get_Slot (1);
   begin
      --  The pair is left in slot 1, so set-car! answers with it.  What
      --  it answers with is unspecified, and write-char is the shape
      --  followed here: something called for its effect gives back what
      --  it was called on.

      if not Raven.Objects.Is_Pair (Pair) then
         raise Constraint_Error with
           "set-car!: not a pair: " & Encode (VM.Display (Pair));
      end if;

      VM.Set_Car (Pair, VM.Get_Slot (2));
   end Set_Car;

   -------------
   -- Set_Cdr --
   -------------

   procedure Set_Cdr (VM : Raven_VM) is
      Pair : constant Object := VM.Get_Slot (1);
   begin
      if not Raven.Objects.Is_Pair (Pair) then
         raise Constraint_Error with
           "set-cdr!: not a pair: " & Encode (VM.Display (Pair));
      end if;

      VM.Set_Cdr (Pair, VM.Get_Slot (2));
   end Set_Cdr;

   ----------------------
   -- String_To_Symbol --
   ----------------------

   procedure String_To_Symbol (VM : Raven_VM) is
   begin
      if not Raven.Strings.Is_String (VM, 1) then
         raise Constraint_Error with
           "string->symbol: not a string: "
           & Encode (VM.Display (VM.Get_Slot (1)));
      end if;

      VM.Set_Slot (1, VM.To_Symbol (Raven.Strings.Get_String (VM, 1)));
   end String_To_Symbol;

   ----------------------
   -- Symbol_To_String --
   ----------------------

   procedure Symbol_To_String (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
   begin
      if not Raven.Objects.Is_Symbol (X) then
         raise Constraint_Error with
           "symbol->string: not a symbol: " & Encode (VM.Display (X));
      end if;

      --  Showing a symbol is writing its name, which is what the
      --  symbol table holds it under and what reading that name gives
      --  the symbol back from.

      Raven.Strings.Write_String (VM, 1, Encode (VM.Display (X)));
   end Symbol_To_String;

end Raven.Scheme;

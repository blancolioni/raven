with Raven.Objects;
with Raven.Strings;
with Raven.Scheme.Numerics;

package body Raven.Scheme is

   procedure Are_Equal (VM : Raven_VM);

   procedure Generate_Symbol (VM : Raven_VM);

   procedure Is_Symbol (VM : Raven_VM);

   ---------------
   -- Are_Equal --
   ---------------

   procedure Are_Equal (VM : Raven_VM) is
      X : constant Object := VM.Get_Slot (1);
      Y : constant Object := VM.Get_Slot (2);
   begin
      VM.Set_Slot (1, VM.Equal (X, Y));
   end Are_Equal;

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

      Raven.Scheme.Numerics.Load_Numeric_Library (Evaluator);
      Raven.Strings.Load_String_Library (Evaluator);
   end Load_Base_Primitives;

end Raven.Scheme;

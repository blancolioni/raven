with Raven.Strings;
with Raven.Scheme.Numerics;

package body Raven.Scheme is

   procedure Are_Equal (VM : Raven_VM);

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
   -- Load_Base_Primitives --
   --------------------------

   procedure Load_Base_Primitives
     (Evaluator : not null access Raven.Evaluator.Abstraction'Class)
   is
   begin
      Evaluator.Bind_Foreign_Function
        ("equal?", Are_Equal'Access, 2);

      Raven.Scheme.Numerics.Load_Numeric_Library (Evaluator);
      Raven.Strings.Load_String_Library (Evaluator);
   end Load_Base_Primitives;

end Raven.Scheme;
